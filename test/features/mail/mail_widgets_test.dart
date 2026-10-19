import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/core/widgets/window/traffic_light_button.dart';
import 'package:jent_web/core/widgets/window/window_drag_area.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/mail/view/labeled_text_field.dart';
import 'package:jent_web/features/mail/view/mail_window.dart';
import 'package:jent_web/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendEmail extends Mock implements SendEmailUseCase {}
class _FakeMessage extends Fake implements EmailMessage {}

Widget l10nWrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

Future<MailBloc> pumpMailWindow(
  WidgetTester tester, {
  Future<void> Function()? sendBehavior,
  VoidCallback? onClose,
  VoidCallback? onMinimize,
  VoidCallback? onExpand,
  ValueChanged<Offset>? onDragDelta,
}) async {
  final sendEmail = _MockSendEmail();
  if (sendBehavior != null) {
    when(() => sendEmail(any())).thenAnswer((_) => sendBehavior());
  }
  final bloc = MailBloc(sendEmail);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: BlocProvider.value(
        value: bloc,
        child: Scaffold(
          body: MailWindow(
            size: const Size(480, 520),
            onClose: onClose ?? () {},
            onMinimize: onMinimize ?? () {},
            onExpand: onExpand ?? () {},
            onDragDelta: onDragDelta ?? (_) {},
            onSend: (draft) => bloc.add(
              SendEmail(
                name: draft.name,
                from: draft.from,
                subject: draft.subject,
                body: draft.body,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return bloc;
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeMessage()));

  group('LabeledTextField', () {
    testWidgets('shows label and hint, forwards typed text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        l10nWrap(
          LabeledTextField(
            label: 'Subject:',
            controller: controller,
            hint: 'Subject',
          ),
        ),
      );

      expect(find.text('Subject:'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hello');
      expect(controller.text, 'Hello');
    });
  });

  group('MailWindow', () {
    testWidgets('chrome buttons call their callbacks', (tester) async {
      var closed = 0;
      var minimized = 0;
      var expanded = 0;
      var dragged = Offset.zero;
      await pumpMailWindow(
        tester,
        onClose: () => closed++,
        onMinimize: () => minimized++,
        onExpand: () => expanded++,
        onDragDelta: (d) => dragged += d,
      );

      Finder light(Color color) => find.byWidgetPredicate(
            (w) => w is TrafficLightButton && w.color == color,
          );
      await tester.tap(light(const Color(0xFFFF5F57)));
      await tester.tap(light(const Color(0xFFFEBC2E)));
      await tester.tap(light(const Color(0xFF28C840)));
      expect(closed, 1);
      expect(minimized, 1);
      expect(expanded, 1);

      await tester.drag(find.byType(WindowDragArea), const Offset(20, 10));
      await tester.pump();
      expect(dragged.dx, greaterThan(0));
      expect(dragged.dy, greaterThan(0));
    });

    testWidgets('send is disabled until subject or body is filled', (
      tester,
    ) async {
      await pumpMailWindow(tester);

      TextButton sendButton() => tester.widget<TextButton>(
            find.widgetWithText(TextButton, 'Send'),
          );
      expect(sendButton().onPressed, isNull);

      // Subject is the third field (name, from, subject).
      await tester.enterText(find.byType(TextField).at(2), 'Hello');
      await tester.pump();
      expect(sendButton().onPressed, isNotNull);
    });

    testWidgets('successful send shows the sent state', (tester) async {
      final bloc = await pumpMailWindow(
        tester,
        sendBehavior: () async {},
      );

      await tester.enterText(find.byType(TextField).at(2), 'Hello');
      await tester.enterText(
        find.byType(TextField).at(3),
        'Body text',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bloc.state.emailStatus.name, 'sent');
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('a sent message keeps the window open and resets itself', (
      tester,
    ) async {
      var closed = 0;
      final bloc = await pumpMailWindow(
        tester,
        onClose: () => closed++,
        sendBehavior: () async {},
      );

      await tester.enterText(find.byType(TextField).at(2), 'Hello');
      await tester.enterText(find.byType(TextField).at(3), 'Body text');
      await tester.tap(find.widgetWithText(TextButton, 'Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Still open, draft cleared, ready for the next message.
      expect(closed, 0, reason: 'a sent message must not close the window');
      expect(find.byType(MailWindow), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).at(3)).controller!.text, isEmpty);

      // The banner fades back to idle on its own.
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(bloc.state.emailStatus.name, 'idle');
      // AnimatedSwitcher keeps the old label for its fade-out.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sent'), findsNothing);
    });

    testWidgets('failed send shows the error state', (tester) async {
      final sendEmail = _MockSendEmail();
      when(() => sendEmail(any())).thenThrow(Exception('smtp'));
      final bloc = MailBloc(sendEmail);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(
              body: MailWindow(
                size: const Size(480, 520),
                onClose: () {},
                onMinimize: () {},
                onExpand: () {},
                onDragDelta: (_) {},
                onSend: (draft) => bloc.add(
                  SendEmail(
                    name: draft.name,
                    from: draft.from,
                    subject: draft.subject,
                    body: draft.body,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(2), 'Hello');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Send'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to send, try again'), findsOneWidget);
    });
  });
}
