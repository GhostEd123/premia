import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:premia/features/films/domain/film.dart';
import 'package:premia/features/parties/presentation/lobby_screen.dart';

void main() {
  final testFilm = Film(
    id: 'film-1',
    title: 'Behind the Scenes: Reloaded',
    description: 'Aderonke Faniran is loved for her generosity...',
    genre: 'Drama • Comedy',
    durationMinutes: 124,
    premiereEnd: DateTime.now().add(const Duration(hours: 41)),
  );

  testWidgets('LobbyScreen renders film details, passes, and house rules',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LobbyScreen(film: testFilm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Behind the Scenes: Reloaded'), findsOneWidget);
    expect(find.textContaining('Aderonke Faniran'), findsOneWidget);
    expect(find.text('Drama • Comedy'), findsOneWidget);
    expect(find.text('Duration: 2 hrs 4 mins'), findsOneWidget);
    expect(find.text('Start Premiere'), findsOneWidget);
    expect(find.text('Guest Passes'), findsOneWidget);
    expect(find.text('Invite to party'), findsOneWidget);
    expect(find.text('House Rules'), findsOneWidget);
    expect(find.textContaining('Watch live. No skipping ahead'), findsOneWidget);
    expect(find.textContaining('Rewind up to 10 minutes'), findsOneWidget);
    expect(find.textContaining('Three pauses per premiere'), findsOneWidget);
  });
}
