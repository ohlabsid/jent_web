import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';

@injectable
class MailBloc extends Bloc<MailEvent, MailState> {
  final SendEmailUseCase _sendEmail;

  MailBloc(this._sendEmail) : super(const MailState()) {
    on<ToggleOpenEmailMenu>(_onToggleEmailMenu);
    on<ToggleCloseEmailMenu>(_onToggleCloseEmailMenu);
    on<ToggleMinimizeEmailMenu>(_onToggleMinimizeEmailMenu);
    on<ToggleExpandEmailMenu>(_onToggleExpandEmailMenu);
    on<SendEmail>(_onSendEmail);
  }

  void _onToggleEmailMenu(
    ToggleOpenEmailMenu event,
    Emitter<MailState> emit,
  ) {
    if (state.isShowWindow) return;

    emit(state.copyWith(isShowWindow: true, isMinimizedWindow: false));
  }

  void _onToggleCloseEmailMenu(
    ToggleCloseEmailMenu event,
    Emitter<MailState> emit,
  ) {
    if (!state.isShowWindow) return;

    emit(state.copyWith(isShowWindow: false, isMinimizedWindow: false));
  }

  void _onToggleMinimizeEmailMenu(
    ToggleMinimizeEmailMenu event,
    Emitter<MailState> emit,
  ) {
    if (!state.isShowWindow) return;

    emit(state.copyWith(isMinimizedWindow: true, isShowWindow: false));
  }

  void _onToggleExpandEmailMenu(
    ToggleExpandEmailMenu event,
    Emitter<MailState> emit,
  ) {
    emit(state.copyWith(isExpandedWindow: !state.isExpandedWindow));
  }

  Future<void> _onSendEmail(SendEmail event, Emitter<MailState> emit) async {
    emit(state.copyWith(emailStatus: EmailStatus.sending));
    try {
      await _sendEmail(
        EmailMessage(
          name: event.name,
          from: event.from,
          subject: event.subject,
          body: event.body,
          captchaToken: event.captchaToken,
        ),
      );
      emit(state.copyWith(emailStatus: EmailStatus.sent));
    } catch (_) {
      emit(state.copyWith(emailStatus: EmailStatus.error));
    }
  }
}
