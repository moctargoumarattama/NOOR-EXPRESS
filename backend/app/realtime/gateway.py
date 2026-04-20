from app.realtime.connection_manager import manager

# Matching and notifications still use the local instance implementation.
# This alias gives us a single swap point for Redis/pub-sub later.
realtime_gateway = manager
driver_locator = realtime_gateway
ride_notifier = realtime_gateway
