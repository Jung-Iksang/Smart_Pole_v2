// Basic Flutter widget test for InfuCare app.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_pole_v2/app.dart';

void main() {
  testWidgets('App launches and shows welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: InfuCareApp(),
      ),
    );

    // Verify that the welcome screen is displayed
    expect(find.text('InfuCare'), findsOneWidget);
  });
}
