import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_patches.dart';
import '../providers/profile_provider.dart';
import '../widgets/edit_sheets/discard_changes_sheet.dart';

/// Full-screen About editor — the one hub section that isn't a quick-edit
/// sheet, because long text + keyboard inside a bottom sheet is cramped.
/// Patches only the role table's `about` column.
class AboutEditPage extends ConsumerStatefulWidget {
  const AboutEditPage({super.key});

  @override
  ConsumerState<AboutEditPage> createState() => _AboutEditPageState();
}

class _AboutEditPageState extends ConsumerState<AboutEditPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;

  String? _nullIfBlank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final isBuilder =
        ref.read(authControllerProvider.select((s) => s.role)) ==
        UserRole.builder;
    final about = Some(_nullIfBlank(values['about'] as String?));

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: isBuilder ? null : TradeProfilePatch(about: about),
          builder: isBuilder ? BuilderProfilePatch(about: about) : null,
        );
    if (!mounted) return;
    if (ok) {
      _dirty = false;
      router.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                AppIcons.successCircle,
                size: AppIconSize.md.r,
                color: Colors.white, // intentional: white-on-success
              ),
              Gap(10.w),
              Text(
                'Profile updated.',
                style: tt.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // intentional: white-on-success
                ),
              ),
            ],
          ),
          backgroundColor: c.verified,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _saving = false);
      final message =
          ref.read(profileControllerProvider).error ??
          "Couldn't save changes. Try again.";
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-error
            ),
          ),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = ref.watch(profileControllerProvider);
    final isBuilder =
        ref.watch(authControllerProvider.select((s) => s.role)) ==
        UserRole.builder;
    final initial = isBuilder
        ? state.builderProfile?.about
        : state.tradeProfile?.about;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDiscardChangesSheet(context);
        if (discard && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: c.card,
                padding: EdgeInsets.fromLTRB(4.w, 8.h, 20.w, 12.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      icon: Icon(
                        AppIcons.back,
                        size: AppIconSize.md.r,
                        color: c.text1,
                      ),
                    ),
                    const Expanded(
                      child: PageHeader(
                        eyebrow: 'EDIT PROFILE',
                        title: 'About',
                        size: PageHeaderSize.sub,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              Expanded(
                child: FormBuilder(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: () {
                    if (!_dirty) setState(() => _dirty = true);
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                    child: JTextField(
                      name: 'about',
                      hint: isBuilder
                          ? 'Tell tradies about your company…'
                          : 'Tell builders about your experience…',
                      initialValue: initial,
                      maxLines: 8,
                      maxLength: 600,
                    ),
                  ),
                ),
              ),
              BottomActionBar(
                primary: JButton(
                  label: 'SAVE',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
