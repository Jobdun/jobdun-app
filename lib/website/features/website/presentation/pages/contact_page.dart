import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../sections/bottom_cta_section.dart';
import '../widgets/animated_cta.dart';
import '../widgets/page_hero.dart';
import '../widgets/site_section_frame.dart';
import '../widgets/site_shell.dart';
import '../widgets/social_links.dart';

/// `/contact`: talk to a human. A hero, then a two-column body (the form on
/// the left, contact details + socials on the right), then the closing CTA.
/// With no backend on the static site, the form composes a pre-filled email to
/// the team via `mailto:` and confirms inline.
class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(
          child: PageHero(
            eyebrow: 'Contact',
            title: 'Talk to a human.',
            subtitle:
                'Questions, partnerships, or you want on the roster early. '
                "drop us a line. We're a small team and we read every one.",
          ),
        ),
        SliverToBoxAdapter(child: _ContactBody()),
        SliverToBoxAdapter(child: BottomCtaSection()),
      ],
    );
  }
}

class _ContactBody extends StatelessWidget {
  const _ContactBody();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: SiteSectionFrame(
        child: wide
            ? const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _ContactForm()),
                  Gap(64),
                  Expanded(flex: 4, child: _ContactDetails()),
                ],
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_ContactForm(), Gap(56), _ContactDetails()],
              ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm();

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _sent = false;

  Future<void> _submit() async {
    final state = _formKey.currentState!;
    if (!state.saveAndValidate()) return;
    final v = state.value;
    final subject = Uri.encodeComponent('Jobdun enquiry: ${v['name']}');
    final body = Uri.encodeComponent(
      'Name: ${v['name']}\n'
      'Email: ${v['email']}\n'
      'I am a: ${v['role']}\n\n'
      '${v['message']}',
    );
    final uri = Uri.parse(
      'mailto:sam@jobdun.com.au?subject=$subject&body=$body',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    if (_sent) return const _SentConfirmation();

    return FormBuilder(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Send us a message',
              style: tt.headlineSmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(24),
          FormBuilderTextField(
            name: 'name',
            decoration: const InputDecoration(labelText: 'Your name'),
            textInputAction: TextInputAction.next,
            validator: FormBuilderValidators.required(),
          ),
          const Gap(16),
          FormBuilderTextField(
            name: 'email',
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.email(),
            ]),
          ),
          const Gap(16),
          FormBuilderDropdown<String>(
            name: 'role',
            decoration: const InputDecoration(labelText: 'I am a…'),
            initialValue: 'Builder',
            items: const [
              DropdownMenuItem(value: 'Builder', child: Text('Builder')),
              DropdownMenuItem(
                value: 'Trade / crew',
                child: Text('Trade / crew'),
              ),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
          ),
          const Gap(16),
          FormBuilderTextField(
            name: 'message',
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 5,
            validator: FormBuilderValidators.required(),
          ),
          const Gap(24),
          AnimatedCta(
            label: 'SEND MESSAGE',
            icon: AppIcons.send,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.verified),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.successCircle, color: c.verified, size: 28),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your email's ready to send.",
                  style: tt.titleMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text(
                  'We just opened it in your mail app. Hit send and we\'ll '
                  'get back to you within a business day.',
                  style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or reach us direct',
          style: tt.titleLarge!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(20),
        const _DetailRow(
          icon: AppIcons.email,
          label: 'General',
          value: 'sam@jobdun.com.au',
          href: 'mailto:sam@jobdun.com.au',
        ),
        const Gap(16),
        const _DetailRow(
          icon: AppIcons.email,
          label: 'Support',
          value: 'support@jobdun.com.au',
          href: 'mailto:support@jobdun.com.au',
        ),
        const Gap(16),
        const _DetailRow(
          icon: AppIcons.location,
          label: 'Based in',
          value: 'Sydney, NSW · serving all of Australia',
        ),
        const Gap(28),
        Text(
          'FOLLOW ALONG',
          style: tt.labelMedium!.copyWith(
            color: c.text3,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(12),
        const SocialLinks(),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.href,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? href;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final valueWidget = Text(
      value,
      style: tt.bodyLarge!.copyWith(
        color: href != null ? c.actionInk : c.text1,
        height: 1.4,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.text2),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: tt.labelSmall!.copyWith(
                  color: c.text3,
                  letterSpacing: 1,
                ),
              ),
              const Gap(2),
              if (href != null)
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(href!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: valueWidget,
                )
              else
                valueWidget,
            ],
          ),
        ),
      ],
    );
  }
}
