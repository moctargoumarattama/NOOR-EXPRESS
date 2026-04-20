import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/app/app.dart';

void main() {
  testWidgets('Noor Express app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NoorExpressApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
