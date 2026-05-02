# Noor Express Ride Chat Design

**Date:** 2026-05-01

## Goal

Add an in-app chat between passenger and driver that is available only while a ride is active, uses the existing realtime channels, and fits the current FastAPI plus Flutter tracking architecture without adding a parallel transport layer.

## Product Promise

- The passenger and driver can exchange short coordination messages during ride statuses `accepted`, `arrived`, and `started`.
- Chat access stops as soon as the ride becomes `completed`, `cancelled`, or `expired`.
- New messages appear in near real time for both sides through the existing websocket connection already used for ride updates.
- The tracking UI exposes a chat bubble only while the ride is chat-eligible.
- If unread messages exist for the current user, the tracking chat bubble shows a red unread counter.

## Scope

### In Scope

- backend message persistence
- message history API with pagination
- authenticated message creation API
- realtime push over the existing client and driver websocket channels
- read-state updates when the recipient loads the chat history
- Flutter tracking entry point for client and driver
- Flutter chat screen, message list, composer, and unread badge
- automated backend and Flutter tests

### Out of Scope

- media attachments
- voice notes
- typing indicators
- delivery state beyond a simple `lu` boolean
- chat access after ride completion
- a second websocket endpoint or second realtime stack

## Existing Architecture Constraints

- FastAPI routes already keep business rules inside services rather than route handlers.
- The backend already exposes a shared realtime gateway for client and driver websocket notifications.
- Flutter tracking currently centralizes live ride state in `TrackingController`, `TrackingWebSocketDatasource`, and the client and driver tracking screens.
- The existing tracking websocket datasource only knows ride status and driver location events; chat should extend this protocol instead of bypassing it.

## Architecture Decision

Use HTTP for message creation and history retrieval, then fan out the created message over the existing websocket channels for the ride participants.

This keeps write validation, authz, and persistence on the normal API surface while still giving both users real-time delivery without introducing a second socket or embedding business logic in the widgets.

## Backend Design

### Data Model

Add a new SQLAlchemy model `RideMessage` linked to `ride_requests`.

Fields:

- `id`
- `ride_id`
- `sender_id`
- `sender_role`
- `content`
- `is_read`
- `created_at`

Rules:

- `content` is required and trimmed
- `content` length is capped at `500` characters
- `is_read` defaults to `false`
- `sender_role` uses the existing `UserRole` enum values

### Service Layer

Add a dedicated service module for ride chat responsibilities.

Responsibilities:

- load the ride and ensure it exists
- ensure the requester is the ride client or assigned driver
- allow chat only while ride status is one of `accepted`, `arrived`, `started`
- reject access after `completed`, `cancelled`, or `expired`
- create a message
- list paginated messages
- mark incoming messages as read for the current user when the history endpoint is called during an active ride
- compute unread count for the current user

The route layer should only translate HTTP inputs and outputs. All ride ownership, status validation, trimming, unread counting, and read-state mutation stay in the service.

### API Surface

Add message routes under the existing ride request router:

- `POST /ride-requests/{ride_request_id}/messages`
- `GET /ride-requests/{ride_request_id}/messages`

Request body for create:

- `content`

Response shape for a message:

- `id`
- `ride_id`
- `sender_id`
- `sender_role`
- `content`
- `is_read`
- `created_at`

History response:

- paginated list of message objects
- `unread_count`
- pagination echo fields already aligned with current app conventions

The current user id must come from the JWT-authenticated user, never from client-supplied ids.

### Realtime Contract

Reuse the existing websocket endpoints:

- `/ws/clients/{client_id}`
- `/ws/drivers/{driver_id}`

Add a new realtime payload type:

- `ride_message`

Payload:

- `type`
- `ride_request_id`
- `message`

Where `message` is the serialized ride message object.

The broadcast flow is:

1. authenticated HTTP `POST`
2. service creates the message
3. backend sends `ride_message` to the ride client websocket
4. backend sends `ride_message` to the ride driver websocket if assigned
5. HTTP response returns the same created message

This allows the sender to rely on the API response immediately while the socket keeps the other participant updated.

### Read-State Semantics

`is_read` means "the recipient opened the chat history after the message was sent while the ride was still chat-eligible."

That means:

- sending a message does not mark it as read
- the sender's own messages remain `is_read = false` until the recipient loads the chat history
- when the recipient loads the history, all messages addressed to them for that ride become `is_read = true`
- once the ride is no longer active, chat history becomes inaccessible and no additional read-state changes occur

## Flutter Design

### Tracking Entry Point

Reuse the existing client and driver tracking screens plus the shared `BottomRideSheet`.

Add a chat bubble action that:

- appears only when ride status is `accepted`, `arrived`, or `started`
- opens a dedicated chat screen
- shows a red badge counter when there are unread incoming messages for the current user
- disappears automatically when the ride leaves chat-eligible states

The button should be driven by controller state, not by inline widget logic.

### Chat Data Flow

Add a small ride-chat data layer that:

- fetches paginated history from the API
- sends new messages through the API
- listens for `ride_message` events through the existing `TrackingWebSocketDatasource`

The tracking websocket datasource should parse chat events and expose them as first-class socket events, similar to ride status and driver location.

### Chat Screen

The screen should:

- render messages chronologically
- place the current user's messages on the right
- place the counterpart's messages on the left
- show a simple `Lu` indicator for the current user's messages when `is_read = true`
- keep styling aligned with the existing tracking and card system
- close or disable itself with a clear message when the ride is no longer chat-eligible

### State Ownership

`TrackingController` remains the source of truth for whether chat is available and for lightweight unread badge state.

A dedicated chat controller can own:

- current message page
- send in-flight state
- pagination state
- local merge of fetched and pushed messages

This keeps ride lifecycle concerns separate from conversation concerns.

## Error Handling

### Backend

- `404` when ride does not exist
- `403` when the authenticated user is not one of the ride participants
- `409` when the ride exists but chat is no longer allowed because status is inactive
- `422` when message content is missing or exceeds `500` characters

### Flutter

- show inline error for send failures
- keep previously loaded messages on pagination failure
- clear unread badge after history refresh marks incoming messages as read
- if ride status changes to `completed`, `cancelled`, or `expired` while chat is open, close the composer path and surface a short explanation

## Files Expected To Change

### Backend

- `backend/app/models/__init__.py`
- `backend/app/models/ride_message.py`
- `backend/app/schemas/ride_request.py`
- `backend/app/api/ride_request.py`
- `backend/app/realtime/schemas.py`
- `backend/app/realtime/connection_manager.py`
- `backend/app/services/ride_message_service.py`
- `backend/alembic/versions/2026_05_01_ride_chat.py`
- backend tests covering routes, service rules, and websocket payloads

### Flutter

- `mobile/lib/features/ride_tracking/data/datasources/tracking_remote_datasource.dart`
- `mobile/lib/features/ride_tracking/data/datasources/tracking_websocket_datasource.dart`
- `mobile/lib/features/ride_tracking/data/models/ride_tracking_model.dart`
- `mobile/lib/features/ride_tracking/domain/entities/tracking_state.dart`
- `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller.dart`
- `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_realtime.dart`
- `mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart`
- `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`
- `mobile/lib/features/ride_tracking/presentation/widgets/bottom_ride_sheet.dart`
- new focused chat screen and models inside the existing `ride_tracking` feature
- Flutter tests for unread badge, status gating, message layout, and read state rendering

## Testing Strategy

### Backend

- message creation allowed for passenger and driver on `accepted`, `arrived`, `started`
- message creation rejected after `completed`
- message access rejected for third-party users
- content validation rejects empty and `>500` characters
- history pagination behaves predictably
- history load marks incoming messages as read
- websocket broadcast emits `ride_message` payload to both participants

### Flutter

- websocket chat payload parsing
- unread badge count visibility
- chat action hidden for inactive statuses
- message bubble alignment
- `Lu` indicator rendering
- chat screen reacts correctly when ride status becomes inactive

## Risks

- unread count can drift if socket and API state are merged carelessly on the client
- large tracking files can become harder to maintain if chat logic is not factored into focused helpers
- chat availability must stay tied to backend ride status, not to local assumptions

## Success Criteria

This design is successful when:

- passenger and driver can coordinate inside Noor Express during active rides
- neither side can access or continue chat after the ride ends
- unread messages are visible from the tracking screen before opening chat
- backend validation prevents oversized or unauthorized messages
- the implementation reuses the existing websocket infrastructure cleanly
