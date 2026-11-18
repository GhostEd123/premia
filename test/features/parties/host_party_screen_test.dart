import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:premia/features/parties/presentation/host_party_screen.dart';

void main() {
  testWidgets('HostPartyScreen renders form inputs and guest list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HostPartyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host party'), findsOneWidget);
    expect(find.text('Each guest gets their own secure Magic Link.'), findsOneWidget);
    expect(find.text('Guest Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Send Magic Link'), findsOneWidget);
    expect(find.text('Guest list'), findsOneWidget);

    // Initial seeded guests
    expect(find.text('Joshua OG'), findsOneWidget);
    expect(find.text('josh@premiamail.com'), findsOneWidget);
    expect(find.text('In lobby'), findsWidgets);
    expect(find.text('Sent'), findsWidgets);
  });

  testWidgets('HostPartyScreen invites a new guest when form is filled',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HostPartyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.first, 'Adaeze Nwosu');
    await tester.enterText(textFields.last, 'adaeze@example.com');
    await tester.pump();

    await tester.tap(find.text('Send Magic Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Adaeze Nwosu'), findsOneWidget);
    expect(find.text('adaeze@example.com'), findsOneWidget);

    // Let the snackbar timer finish
    await tester.pump(const Duration(seconds: 3));
  });
}
