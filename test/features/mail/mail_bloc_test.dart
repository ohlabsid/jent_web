import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendEmail extends Mock implements SendEmailUseCase {}
class _FakeMessage extends Fake implements EmailMessage {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeMessage()));

  late SendEmailUseCase sendEmail;

  setUp(() {
    sendEmail = _MockSendEmail();
  });

  MailBloc buildBloc() => MailBloc(sendEmail);

  group('mail window toggles derive from state', () {
    blocTest<MailBloc, MailState>(
      'opens only once; second open is a no-op',
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(ToggleOpenEmailMenu())
          ..add(ToggleOpenEmailMenu());
      },
      expect: () => [
        isA<MailState>()
            .having((s) => s.isShowWindow, 'isShowWindow', true)
            .having(
              (s) => s.isMinimizedWindow,
              'isMinimizedWindow',
              false,
            ),
      ],
    );

    blocTest<MailBloc, MailState>(
      'close then minimize toggle window flags',
      build: buildBloc,
      seed: () => MailState(
        isShowWindow: true,
      ),
      act: (bloc) {
        bloc
          ..add(ToggleCloseEmailMenu())
          ..add(ToggleOpenEmailMenu())
          ..add(ToggleMinimizeEmailMenu());
      },
      expect: () => [
        isA<MailState>()
            .having((s) => s.isShowWindow, 'shown', false)
            .having((s) => s.isMinimizedWindow, 'minimized', false),
        isA<MailState>()
            .having((s) => s.isShowWindow, 'shown', true)
            .having((s) => s.isMinimizedWindow, 'minimized', false),
        isA<MailState>()
            .having((s) => s.isShowWindow, 'shown', false)
            .having((s) => s.isMinimizedWindow, 'minimized', true),
      ],
    );

    blocTest<MailBloc, MailState>(
      'minimized mail keeps its dock status until closed',
      build: buildBloc,
      seed: () => MailState(
        isShowWindow: false,
        isMinimizedWindow: true,
      ),
      act: (bloc) {
        bloc
          ..add(ToggleOpenEmailMenu())
          ..add(ToggleCloseEmailMenu());
      },
      expect: () => [
        isA<MailState>()
            .having((s) => s.isShowWindow, 'shown', true)
            .having((s) => s.isMinimizedWindow, 'minimized', false),
        isA<MailState>()
            .having((s) => s.isShowWindow, 'shown', false)
            .having((s) => s.isMinimizedWindow, 'minimized', false),
      ],
    );

    blocTest<MailBloc, MailState>(
      'expand toggles from current state',
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(ToggleExpandEmailMenu())
          ..add(ToggleExpandEmailMenu());
      },
      expect: () => [
        isA<MailState>()
            .having((s) => s.isExpandedWindow, 'expanded', true),
        isA<MailState>()
            .having((s) => s.isExpandedWindow, 'expanded', false),
      ],
    );
  });

  group('send email', () {
    const event = (
      name: 'Ada',
      from: 'ada@mail.com',
      subject: 'Hi',
      body: 'Hello',
    );

    blocTest<MailBloc, MailState>(
      'emits sending then sent on success',
      build: () {
        when(() => sendEmail(any())).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        SendEmail(
          name: event.name,
          from: event.from,
          subject: event.subject,
          body: event.body,
        ),
      ),
      expect: () => [
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.sending),
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.sent),
      ],
      verify: (_) => verify(
        () => sendEmail(
          any(
            that: isA<EmailMessage>()
                .having((m) => m.subject, 'subject', 'Hi')
                .having((m) => m.body, 'body', 'Hello'),
          ),
        ),
      ).called(1),
    );

    blocTest<MailBloc, MailState>(
      'forwards the hCaptcha token to the repository',
      build: () {
        when(() => sendEmail(any())).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        SendEmail(
          name: event.name,
          from: event.from,
          subject: event.subject,
          body: event.body,
          captchaToken: 'token-abc',
        ),
      ),
      expect: () => [
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.sending),
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.sent),
      ],
      verify: (_) => verify(
        () => sendEmail(
          any(
            that: isA<EmailMessage>()
                .having((m) => m.captchaToken, 'captchaToken', 'token-abc'),
          ),
        ),
      ).called(1),
    );

    blocTest<MailBloc, MailState>(
      'emits sending then error on failure',
      build: () {
        when(() => sendEmail(any())).thenThrow(Exception('smtp'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        SendEmail(
          name: event.name,
          from: event.from,
          subject: event.subject,
          body: event.body,
        ),
      ),
      expect: () => [
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.sending),
        isA<MailState>()
            .having((s) => s.emailStatus, 'status', EmailStatus.error),
      ],
    );
  });
}
