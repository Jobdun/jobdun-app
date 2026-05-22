import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../services/places_service.dart';
import '../../theme/app_icons.dart';

/// Suggestion / loading / empty panel rendered beneath [JPlaceField] while the
/// input has focus and a query is in flight. Public so the field file stays
/// inside the 500-LOC ceiling enforced by `scripts/validate.sh`.
///
/// The panel is purely presentational — every state change comes back to the
/// parent through one of the callbacks, and the parent owns timers, focus,
/// and the actual form value.
class JPlaceDropdown extends StatelessWidget {
  const JPlaceDropdown({
    super.key,
    required this.suggestions,
    required this.loading,
    required this.resolvingCurrentLocation,
    required this.noResults,
    required this.onSelect,
    required this.onUseCurrentLocation,
  });

  /// Up to 5 places, already AU-filtered and parsed by the service.
  final List<JPlaceResult> suggestions;

  /// True while the HTTP request is in flight (after the 250 ms debounce).
  /// When true the rows render as skeleton bars regardless of [suggestions].
  final bool loading;

  /// True while we're reverse-geocoding the device position. Replaces the
  /// chip's icon with an inline spinner and disables tap.
  final bool resolvingCurrentLocation;

  /// True when the request succeeded but produced no AU-matchable rows —
  /// shows the "No matches" copy instead of the skeleton.
  final bool noResults;

  final ValueChanged<JPlaceResult> onSelect;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: [
          _CurrentLocationTile(
            loading: resolvingCurrentLocation,
            onTap: onUseCurrentLocation,
          ),
          Divider(height: 1, color: c.border),
          if (loading)
            const _LoadingRows()
          else if (suggestions.isNotEmpty)
            _SuggestionsList(suggestions: suggestions, onSelect: onSelect)
          else if (noResults)
            const _NoMatchesRow(),
        ],
      ),
    );
  }
}

class _CurrentLocationTile extends StatelessWidget {
  const _CurrentLocationTile({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            SizedBox(
              width: 20.r,
              height: 20.r,
              child: loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Icon(AppIcons.gps, size: 18.r, color: c.action),
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                loading ? 'FINDING YOUR LOCATION…' : 'USE MY CURRENT LOCATION',
                style: tt.labelMedium!.copyWith(
                  color: c.action,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.suggestions, required this.onSelect});

  final List<JPlaceResult> suggestions;
  final ValueChanged<JPlaceResult> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        for (var i = 0; i < suggestions.length; i++) ...[
          _SuggestionRow(
            result: suggestions[i],
            onTap: () => onSelect(suggestions[i]),
          ),
          if (i < suggestions.length - 1) Divider(height: 1, color: c.border),
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.result, required this.onTap});

  final JPlaceResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Icon(AppIcons.location, size: 18.r, color: c.text3),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.mainText,
                    style: tt.bodyLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    result.secondaryText,
                    style: tt.bodySmall!.copyWith(color: c.text3),
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

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Icon(AppIcons.location, size: 18.r, color: c.text3),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12.h, width: 140.w, color: c.surface),
                    Gap(6.h),
                    Container(height: 10.h, width: 90.w, color: c.surface),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _NoMatchesRow extends StatelessWidget {
  const _NoMatchesRow();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Text(
        'No matches. Try a postcode or a nearby suburb.',
        style: tt.bodySmall!.copyWith(color: c.text3),
      ),
    );
  }
}
