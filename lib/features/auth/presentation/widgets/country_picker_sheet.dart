import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/validators/phone_validator.dart';

// Modal bottom sheet for picking the country dial code. Small fixed list —
// `supportedCountries` from the validator. Returns the picked Country (or
// null if dismissed).
Future<Country?> showCountryPickerSheet(
  BuildContext context, {
  String? currentCode,
}) {
  return showJSheet<Country>(
    context: context,
    builder: (_) => _CountryPickerSheet(currentCode: currentCode),
  );
}

class _CountryPickerSheet extends StatelessWidget {
  const _CountryPickerSheet({this.currentCode});

  final String? currentCode;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card.r),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
              child: Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                4.h,
                AppSpacing.lg.w,
                12.h,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PICK YOUR COUNTRY',
                      style: tt.labelSmall!.copyWith(
                        letterSpacing: 0.12 * 11,
                        color: c.text1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      AppIcons.closeBox,
                      size: AppIconSize.md.r,
                      color: c.text3,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg.w,
                  0,
                  AppSpacing.lg.w,
                  24.h,
                ),
                itemCount: supportedCountries.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final country = supportedCountries[i];
                  final selected = country.code == currentCode;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(country),
                    borderRadius: BorderRadius.circular(AppRadius.input.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 14.h,
                      ),
                      child: Row(
                        children: [
                          // Emoji flag glyph — decorative sizing only, not
                          // type-scale text (font family/weight/spacing don't
                          // apply to emoji). Left raw by design.
                          Text(country.flag, style: TextStyle(fontSize: 22)),
                          Gap(12.w),
                          Expanded(
                            child: Text(
                              country.name,
                              style: tt.bodyLarge!.copyWith(
                                color: c.text1,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '+${country.dialCode}',
                            style: tt.bodyMedium!.copyWith(color: c.text2),
                          ),
                          if (selected) ...[
                            Gap(10.w),
                            Icon(
                              AppIcons.successCircle,
                              size: AppIconSize.md.r,
                              color: c.action,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
