import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jent_web/core/theme/app_colors.dart';
import 'package:jent_web/core/theme/app_dimens.dart';
import 'package:jent_web/core/widgets/window/window_title_bar.dart';
import 'package:jent_web/features/mail/captcha/hcaptcha.dart';
import 'package:jent_web/l10n/app_localizations.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';
import 'package:jent_web/features/mail/view/labeled_text_field.dart';

class MailWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onExpand;
  final Size size;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<MailDraft> onSend;

  const MailWindow({
    super.key,
    required this.onClose,
    required this.onMinimize,
    required this.onExpand,
    required this.size,
    required this.onDragDelta,
    required this.onSend,
  });

  @override
  State<MailWindow> createState() => _MailWindowState();
}

class MailDraft {
  final String name;
  final String from;
  final String subject;
  final String body;

  /// hCaptcha token, or null where the form has no captcha (native).
  final String? captchaToken;

  const MailDraft({
    required this.name,
    required this.from,
    required this.subject,
    required this.body,
    this.captchaToken,
  });

  bool get canSend =>
      subject.trim().isNotEmpty || body.trim().isNotEmpty;
}

class _MailWindowState extends State<MailWindow> {
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  /// Real hCaptcha on web, no-op on native (SMTP needs no captcha).
  final HCaptcha _captcha = createHCaptcha();

  MailDraft get _draft => MailDraft(
        name: _nameController.text,
        from: _fromController.text,
        subject: _subjectController.text,
        body: _bodyController.text,
        captchaToken: _captcha.token,
      );

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _fromController,
      _subjectController,
      _bodyController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fromController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final draft = _draft;
    if (!draft.canSend) return;
    widget.onSend(draft);
    // Tokens are single-use and expire quickly, so drop the solved
    // challenge right after handing it over: a failed send then shows
    // a fresh checkbox instead of a silently rejected token.
    _captcha.reset();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final emailStatus =
        context.select<MailBloc, EmailStatus>((b) => b.state.emailStatus);
    final sending = emailStatus == EmailStatus.sending;
    // With spam protection on, Web3Forms rejects untokened submissions,
    // so Send stays disabled until the challenge is solved.
    final captchaSolved = !_captcha.isSupported || _captcha.token != null;
    final canSend = _draft.canSend && captchaSolved && !sending;

    return Material(
      elevation: 24,
      borderRadius: BorderRadius.circular(AppDimens.windowRadius),
      clipBehavior: Clip.antiAlias,
      color: AppColors.deepWaterColor,
      child: SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: Column(
          children: [
            WindowTitleBar(
              onClose: widget.onClose,
              onMinimize: widget.onMinimize,
              onExpand: widget.onExpand,
              onPanUpdate: widget.onDragDelta,
            ),
            const Divider(height: 1),
            LabeledTextField(
              label: '${localizations.textName}:',
              controller: _nameController,
              hint: localizations.textNameHint,
            ),
            const Divider(height: 1, indent: 16),
            LabeledTextField(
              label: '${localizations.textFrom}:',
              controller: _fromController,
              hint: localizations.textFromHint,
            ),
            const Divider(height: 1, indent: 16),
            LabeledTextField(
              label: '${localizations.textSubject}:',
              controller: _subjectController,
              hint: localizations.textSubjectHint,
            ),
            const Divider(height: 1, indent: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: localizations.textWriteYourMessageHint,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: AppDimens.bodyFontSize),
                ),
              ),
            ),
            if (_captcha.isSupported)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 303,
                    height: 78,
                    child: _captcha.buildWidget(
                      onToken: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: emailStatus == EmailStatus.sent
                          ? Padding(
                              key: const ValueKey('sent'),
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                localizations.textSentWithIcon,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : emailStatus == EmailStatus.error
                              ? Padding(
                                  key: const ValueKey('error'),
                                  padding:
                                      const EdgeInsets.only(right: 12),
                                  child: Text(
                                    localizations.textSendError,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('idle')),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppDimens.buttonRadius),
                      color: canSend
                          ? AppColors.sendButtonEnabled
                          : AppColors.sendButtonDisabled,
                    ),
                    child: TextButton(
                      onPressed: canSend ? _handleSend : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              localizations.textSend,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
