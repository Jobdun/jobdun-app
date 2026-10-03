import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../profile/domain/entities/apprenticeship_stage.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../domain/entities/job_application.dart';

/// Profile identity remains useful when an older application lacks its joins.
class ApplicantApprenticeshipIdentity extends StatelessWidget {
  const ApplicantApprenticeshipIdentity({
    super.key,
    required this.application,
    this.profile,
  });
  final JobApplication application;
  final TradeProfile? profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final apprentice = profile?.isApprentice ?? application.tradeIsApprentice;
    final stage =
        profile?.apprenticeshipStage ??
        ApprenticeshipStageX.fromDb(application.tradeApprenticeshipStage);
    final trade = profile?.displayTrade ?? application.tradePrimaryTrade ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          application.jobKind == 'apprenticeship'
              ? 'Apprenticeship application'
              : 'Apprentice profile',
          style: tt.titleLarge!.copyWith(color: c.text1),
        ),
        if (apprentice) ...[
          Gap(8.h),
          Text(
            stage?.headline(trade) ?? 'Apprentice',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
        ],
      ],
    );
  }
}
