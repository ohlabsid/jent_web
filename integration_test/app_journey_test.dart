import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jent_web/app.dart';
import 'package:jent_web/core/widgets/background/water_fill_logo.dart';
import 'package:jent_web/core/widgets/window/traffic_light_button.dart';
import 'package:jent_web/di/injection.dart';
import 'package:jent_web/features/desktop/widgets/home_dock.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/view/mail_window.dart';
import 'package:jent_web/features/music/view/music_window_overlay.dart';

/// Full app journey on the real DI graph: ignite loading -> greetings
/// -> home desktop -> mail, photos, notes (guest), and music flows.
///
/// Locale-independent: the device language decides all strings, so
/// every lookup uses keys, types, or icons — never hardcoded text
/// (except locale-free data like note bodies and 'Pritjent').
///
/// External services are absent in tests (no secrets, no network), so
/// this asserts the graceful paths: music plays the bundled demo
/// catalog, sending shows the error state instead of crashing.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder dockIcon(String name) => find.byKey(ValueKey('dock-icon-$name'));

  Finder dockDot() => find.descendant(
        of: find.byType(HomeDock),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        }),
      );

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int seconds = 15,
  }) async {
    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<void> waitForAbsent(
    WidgetTester tester,
    Finder finder, {
    int seconds = 10,
  }) async {
    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (finder.evaluate().isEmpty) return;
    }
  }

  Future<void> reachHome(WidgetTester tester) async {
    // getIt forbids double registration across tests in one run.
    if (!getIt.isRegistered<MailBloc>()) configureDependencies();
    await tester.pumpWidget(const App());

    // First launch shows ignite loading; later tests reuse the static
    // router, which still sits on /home — both are valid entries.
    if (find.byType(WaterFillLogo).evaluate().isNotEmpty) {
      // ~2.5s of progress ticks, then the greeting sequence.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('hello'), findsOneWidget);

      // Tap the first greeting to prove tap-to-skip, then poll for the
      // desktop (device locale decides the final language).
      await tester.tap(find.text('hello'));
      await tester.pump();
      expect(find.text('hola'), findsOneWidget);
    }

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Pritjent').evaluate().isNotEmpty) break;
    }
    expect(find.text('Pritjent'), findsOneWidget);
    expect(dockIcon('email'), findsOneWidget);
    expect(dockIcon('photos'), findsOneWidget);
    expect(dockDot(), findsNothing);
  }

  Finder redLight() => find.byWidgetPredicate(
        (w) => w is TrafficLightButton && w.color == const Color(0xFFFF5F57),
      );

  testWidgets('mail: compose, fail gracefully, close', (tester) async {
    await reachHome(tester);

    await tester.tap(dockIcon('email'));
    await waitFor(tester, find.byType(MailWindow));
    expect(find.byType(MailWindow), findsOneWidget);
    expect(dockDot(), findsOneWidget);

    // Subject is the third field (name, from, subject).
    await tester.enterText(find.byType(TextField).at(2), 'Hello');
    await tester.enterText(find.byType(TextField).at(3), 'Body text');
    await tester.tap(find.descendant(
      of: find.byType(MailWindow),
      matching: find.byType(TextButton),
    ));
    // No Web3Forms key in tests: the error card shows, no crash.
    await waitFor(tester, find.byKey(const ValueKey('error')));
    expect(find.byKey(const ValueKey('error')), findsOneWidget);

    // Close via the red traffic light.
    await tester.tap(redLight());
    await waitForAbsent(tester, find.byType(MailWindow));
    expect(find.byType(MailWindow), findsNothing);
    expect(dockDot(), findsNothing);
  });

  testWidgets('photos: PIN gate, gallery, viewer, close', (tester) async {
    await reachHome(tester);

    await tester.tap(dockIcon('photos'));
    await waitFor(tester, find.byKey(const ValueKey('photos-pin-card')));
    expect(find.byKey(const ValueKey('photos-pin-card')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await waitFor(tester, find.byType(GridView));
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('photo-cell-0')));
    await waitFor(tester, find.byType(InteractiveViewer));
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await waitFor(tester, find.byType(GridView));
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('notes: wrong PIN leads to read-only general notes', (
    tester,
  ) async {
    await reachHome(tester);

    await tester.tap(dockIcon('notes'));
    await waitFor(tester, find.byKey(const ValueKey('notes-pin-card')));
    expect(find.byKey(const ValueKey('notes-pin-card')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await waitFor(tester, find.byIcon(Icons.notes_rounded));

    // Guest entry point on the denied card.
    await tester.tap(find.ancestor(
      of: find.byIcon(Icons.notes_rounded),
      matching: find.byType(TextButton),
    ));
    await waitFor(tester, find.text('Welcome!'));
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Welcome to Notes'), findsNothing);
    // No compose action for guests.
    expect(find.byIcon(Icons.edit_square), findsNothing);
  });

  testWidgets('music: library window opens and lists demo tracks', (
    tester,
  ) async {
    await reachHome(tester);

    await tester.tap(dockIcon('music'));
    await waitFor(tester, find.byType(MusicWindowOverlay));
    expect(find.byType(MusicWindowOverlay), findsOneWidget);

    // Sidebar plus the bundled catalog rows.
    await waitFor(tester, find.byKey(const ValueKey('music-row-0')));
    expect(find.byKey(const ValueKey('music-row-0')), findsOneWidget);
  });
}
