abstract class MailEvent {}

class ToggleOpenEmailMenu extends MailEvent {}

class ToggleCloseEmailMenu extends MailEvent {}

class ToggleMinimizeEmailMenu extends MailEvent {}

class ToggleExpandEmailMenu extends MailEvent {}

class SendEmail extends MailEvent {
  final String name;
  final String from;
  final String subject;
  final String body;

  /// hCaptcha token collected by the form; forwarded to Web3Forms.
  final String? captchaToken;

  SendEmail({
    required this.name,
    required this.from,
    required this.subject,
    required this.body,
    this.captchaToken,
  });
}
