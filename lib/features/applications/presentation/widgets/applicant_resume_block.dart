import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/widgets/section_label.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/resume_row.dart';

/// An applicant's resume, on the builder's hire-decision screen.
///
/// This is the ONE surface where a builder is entitled to open it: the
/// apprentice has applied to their job, which is exactly the relationship
/// `private_docs_resume_applied_builder_select` encodes. The signed URL is
/// minted on tap and lives 60 minutes, so it is never cached or embedded.
///
/// If Postgres refuses (no application, or the row was withdrawn between the
/// page loading and the tap), the failure surfaces as a message rather than a
/// silent no-op — the policy denying access is a real answer, not a bug.
class ApplicantResumeBlock extends ConsumerStatefulWidget {
  const ApplicantResumeBlock({super.key, required this.profile});

  final TradeProfile profile;

  @override
  ConsumerState<ApplicantResumeBlock> createState() =>
      _ApplicantResumeBlockState();
}

class _ApplicantResumeBlockState extends ConsumerState<ApplicantResumeBlock> {
  bool _opening = false;

  Future<void> _open() async {
    final path = widget.profile.resumePath;
    if (path == null || path.isEmpty || _opening) return;
    setState(() => _opening = true);

    final result = await ref.read(getResumeUrlUseCaseProvider).call(path);
    if (!mounted) return;
    setState(() => _opening = false);

    await result.fold(
      (f) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open that resume.")),
        );
      },
      (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.hasResume) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionLabel('Resume'),
        ResumeRow.viewer(onView: _open),
      ],
    );
  }
}
