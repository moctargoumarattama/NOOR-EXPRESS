import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/screens/ride_chat_screen.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/ride_chat_fab.dart';

void main() {
  test('RideChatMessageModel trims payload text and parses unread metadata', () {
    final message = RideChatMessageModel.fromJson({
      'id': 4,
      'ride_id': 8,
      'sender_id': 12,
      'sender_role': 'driver',
      'content': '  Je suis devant la porte bleue  ',
      'is_read': false,
      'created_at': '2026-05-01T08:30:00Z',
    });

    expect(message.content, 'Je suis devant la porte bleue');
    expect(message.isRead, isFalse);
    expect(message.rideId, 8);
  });

  test('RideTrackingModel exposes chat availability only for active ride chat statuses',
      () {
    expect(_buildRide('accepted').canUseChat, isTrue);
    expect(_buildRide('arrived').canUseChat, isTrue);
    expect(_buildRide('started').canUseChat, isTrue);
    expect(_buildRide('completed').canUseChat, isFalse);
    expect(_buildRide('cancelled').canUseChat, isFalse);
  });

  testWidgets('RideChatFab shows an unread badge only when needed',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RideChatFab(
              unreadCount: 3,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Ouvrir le chat'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RideChatFab(
              unreadCount: 0,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('3'), findsNothing);
  });

  testWidgets('RideChatScreen renders sent messages with Lu indicator',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideChatScreen.preview(
          title: 'Votre chauffeur',
          isChatAvailable: true,
          currentUserId: 45,
          messages: [
            RideChatMessageModel(
              id: 1,
              rideId: 8,
              senderId: 12,
              senderRole: 'driver',
              content: 'Je suis devant la porte bleue',
              isRead: true,
              createdAt: DateTime(2026, 5, 1, 8, 30),
            ),
            RideChatMessageModel(
              id: 2,
              rideId: 8,
              senderId: 45,
              senderRole: 'client',
              content: 'J arrive dans 2 minutes',
              isRead: true,
              createdAt: DateTime(2026, 5, 1, 8, 31),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Je suis devant la porte bleue'), findsOneWidget);
    expect(find.text('J arrive dans 2 minutes'), findsOneWidget);
    expect(find.text('Lu'), findsOneWidget);
    expect(find.byKey(const Key('chat-message-peer-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-message-self-2')), findsOneWidget);
  });

  testWidgets('RideChatScreen shows a closed-state message when ride chat is inactive',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RideChatScreen.preview(
          title: 'Votre chauffeur',
          isChatAvailable: false,
          currentUserId: 45,
          messages: [],
        ),
      ),
    );

    expect(find.text('Le chat n est plus disponible pour cette course.'), findsOneWidget);
  });
}

RideTrackingModel _buildRide(String status) {
  return RideTrackingModel(
    id: 8,
    clientId: 45,
    driverId: 12,
    pickupLocation: 'Rond-point Kennedy',
    dropoffLocation: 'Aeroport',
    estimatedPrice: 2500,
    createdAt: DateTime(2026, 5, 1, 8),
    status: RideTrackingModel.fromRawStatus(status),
  );
}

void _noop() {}
