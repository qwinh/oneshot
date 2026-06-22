// Basic smoke test confirming the app boots to the login screen when no
// user is authenticated. The previous version of this file was leftover
// boilerplate from `flutter create` (it referenced a `MyApp` counter
// widget that doesn't exist in this project) and would fail to compile.
//
// This test does not initialize Firebase, so it renders LoginScreen
// directly rather than pumping OneShotApp (which calls Firebase.initializeApp
// in main() before runApp).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneshot/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders the core sign-in fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('ONESHOT'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
