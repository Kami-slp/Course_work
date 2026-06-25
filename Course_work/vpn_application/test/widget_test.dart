import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_application/main.dart';

void main() {
  testWidgets('App shows auth screen when not logged in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Kami-sleep VPN'), findsWidgets);
    expect(find.text('Вход'), findsOneWidget);
  });
}
