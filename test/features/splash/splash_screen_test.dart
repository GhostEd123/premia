import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:premia/core/routing/route_paths.dart';
import 'package:premia/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({Duration? displayDuration}) {
    final router = GoRouter(
      initialLocation: RoutePaths.splash,
      routes: [
        GoRoute(
          path: RoutePaths.splash,
          builder: (_, _) => SplashScreen(
            displayDuration: displayDuration ?? const Duration(milliseconds: 3000),
          ),
        ),
        GoRoute(
          path: RoutePaths.marquee,
          builder: (_, _) => const Scaffold(body: Text('Marquee Screen')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders splash image and starts animations', (tester) async {
    await tester.pumpWidget(buildTestApp());

    // Verify Image asset is present
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, equals('assets/images/splash_screen.png'));

    // Advance animation partially
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Let remaining timers complete
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to marquee when display duration expires', (tester) async {
    await tester.pumpWidget(
      buildTestApp(displayDuration: const Duration(milliseconds: 1000)),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Marquee Screen'), findsNothing);

    // Pump past the display duration
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(find.text('Marquee Screen'), findsOneWidget);
  });

  testWidgets('tap anywhere skips splash immediately to marquee', (tester) async {
    await tester.pumpWidget(
      buildTestApp(displayDuration: const Duration(milliseconds: 5000)),
    );

    expect(find.byType(SplashScreen), findsOneWidget);

    // Tap on the splash screen
    await tester.tap(find.byType(SplashScreen));
    await tester.pumpAndSettle();

    expect(find.text('Marquee Screen'), findsOneWidget);
  });
}
