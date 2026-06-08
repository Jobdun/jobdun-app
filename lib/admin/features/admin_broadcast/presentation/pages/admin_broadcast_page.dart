import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/broadcast_audience.dart';
import '../providers/admin_broadcast_provider.dart';
import '../widgets/admin_broadcast_audience_selector.dart';
import '../widgets/admin_broadcast_preview_card.dart';

/// Compose + send an announcement (push + in-app) to a targeted audience.
/// Mirrors the admin form pattern: a [FormBuilder] validated on submit, a live
/// preview, a confirm dialog (high-impact), and a success snackbar with the
/// recipient count. Repurposes the REPORTS slot in the shell nav.
class AdminBroadcastPage extends ConsumerStatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  ConsumerState<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends ConsumerState<AdminBroadcastPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  BroadcastAudience _audience = BroadcastAudience.all;
  String _title = '';
  String _body = '';
  bool _sending = false;

  /// The audience token the RPC resolves. For a single user it's the typed
  /// profile id; otherwise the segment token (`all` / `builders` / `trades`).
  String _audienceToken(Map<String, dynamic> values) =>
      _audience == BroadcastAudience.singleUser
      ? (values['userId'] as String? ?? '').trim()
      : _audience.value;

  Future<void> _onSendPressed() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final values = form.value;
    final confirmed = await _confirm();
    if (confirmed != true || !mounted) return;
    await _send(_audienceToken(values));
  }

  Future<bool?> _confirm() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmSendDialog(
        audienceLabel: _audience.label,
        title: _title.trim(),
      ),
    );
  }

  Future<void> _send(String audienceToken) async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final res = await ref
        .read(adminBroadcastProvider)
        .send(
          title: _title.trim(),
          body: _body.trim(),
          audience: audienceToken,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    res.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (count) {
        _formKey.currentState?.reset();
        setState(() {
          _title = '';
          _body = '';
          _audience = BroadcastAudience.all;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Sent to 1 recipient.'
                  : 'Sent to $count recipients.',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AdminScaffold(
      title: 'BROADCAST',
      activeRoute: AdminRoutes.broadcast,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BROADCAST', style: AdminText.display(c.text1)),
              const Gap(8),
              Text(
                'Send a push + in-app update to your users. Everyone in the '
                'audience receives it instantly.',
                style: AdminText.body(c.text2),
              ),
              const Gap(28),
              _ComposeForm(
                formKey: _formKey,
                audience: _audience,
                onAudienceChanged: (a) => setState(() => _audience = a),
                onTitleChanged: (v) => setState(() => _title = v ?? ''),
                onBodyChanged: (v) => setState(() => _body = v ?? ''),
              ),
              const Gap(24),
              Text('PREVIEW', style: AdminText.cardLabel(c.text3)),
              const Gap(10),
              AdminBroadcastPreviewCard(title: _title, body: _body),
              const Gap(28),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: JButton(
                      label: 'SEND BROADCAST',
                      icon: AppIcons.send,
                      isLoading: _sending,
                      onPressed: _sending ? null : _onSendPressed,
                    ),
                  ),
                ],
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }
}

/// The compose fields — audience selector, an optional single-user id field,
/// then TITLE + MESSAGE. Split out so the page's build stays shallow.
class _ComposeForm extends StatelessWidget {
  const _ComposeForm({
    required this.formKey,
    required this.audience,
    required this.onAudienceChanged,
    required this.onTitleChanged,
    required this.onBodyChanged,
  });

  final GlobalKey<FormBuilderState> formKey;
  final BroadcastAudience audience;
  final ValueChanged<BroadcastAudience> onAudienceChanged;
  final ValueChanged<String?> onTitleChanged;
  final ValueChanged<String?> onBodyChanged;

  @override
  Widget build(BuildContext context) {
    final isSingle = audience == BroadcastAudience.singleUser;
    return FormBuilder(
      key: formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBroadcastAudienceSelector(
            value: audience,
            onChanged: onAudienceChanged,
          ),
          if (isSingle) ...[
            const Gap(16),
            JTextField(
              name: 'userId',
              label: 'USER ID',
              hint: 'profile id (uuid)',
              validator: isSingle
                  ? FormBuilderValidators.required(
                      errorText: 'Enter the recipient profile id.',
                    )
                  : null,
            ),
          ],
          const Gap(16),
          JTextField(
            name: 'title',
            label: 'TITLE',
            hint: 'e.g. New verification flow is live',
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            onChanged: onTitleChanged,
            validator: FormBuilderValidators.required(
              errorText: 'A title is required.',
            ),
          ),
          const Gap(8),
          JTextField(
            name: 'body',
            label: 'MESSAGE',
            hint: 'What do you want users to know?',
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            maxLength: 240,
            onChanged: onBodyChanged,
            validator: FormBuilderValidators.required(
              errorText: 'A message is required.',
            ),
          ),
        ],
      ),
    );
  }
}

/// High-impact confirm dialog before a broadcast goes out. Mirrors the admin
/// revoke dialog: [c.surface] background, [AdminText.dialogTitle], CANCEL +
/// CONFIRM [JButton] pair.
class _ConfirmSendDialog extends StatelessWidget {
  const _ConfirmSendDialog({required this.audienceLabel, required this.title});

  final String audienceLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        'Send this broadcast?',
        style: AdminText.dialogTitle(c.text1).copyWith(fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This sends a push + in-app notification to $audienceLabel. '
            'It cannot be unsent.',
            style: AdminText.value(c.text2).copyWith(height: 1.4),
          ),
          if (title.isNotEmpty) ...[
            const Gap(12),
            Text('"$title"', style: AdminText.bodyStrong(c.text1)),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: 110,
          child: JButton(
            label: 'CANCEL',
            variant: JButtonVariant.secondary,
            size: JButtonSize.compact,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        SizedBox(
          width: 130,
          child: JButton(
            label: 'SEND',
            size: JButtonSize.compact,
            icon: AppIcons.send,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }
}
