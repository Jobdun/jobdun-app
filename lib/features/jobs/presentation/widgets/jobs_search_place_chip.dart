import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/services/places_service_provider.dart';
import '../../../../core/theme/app_icons.dart';

/// Below-the-search-bar match chip on /jobs.
///
/// Listens to [query] and asks [placesServiceProvider] for AU-restricted
/// suggestions on the same 250 ms / 3-char rules JPlaceField uses. When the
/// service returns at least one confident suburb match, renders a single
/// tappable chip:
///
///   [📍 SUBURB: PARRAMATTA NSW]
///
/// Tapping calls [onTap] with the top match — the parent then rewrites the
/// search input to the structured suburb name. The lat/lng radius scope on
/// jobsRepository.search() is a follow-up; the current jobs feed already
/// matches against suburb/state strings, so the chip is functional out of
/// the gate.
///
/// Renders an empty `SizedBox.shrink()` when:
///   - query is shorter than the 3-char minimum, or
///   - the service throws (no error UI here — silent degradation, the chip
///     is purely additive enhancement, not a primary path).
class JobsSearchPlaceChip extends ConsumerStatefulWidget {
  const JobsSearchPlaceChip({
    super.key,
    required this.query,
    required this.onTap,
  });

  final String query;
  final ValueChanged<JPlaceResult> onTap;

  @override
  ConsumerState<JobsSearchPlaceChip> createState() =>
      _JobsSearchPlaceChipState();
}

class _JobsSearchPlaceChipState extends ConsumerState<JobsSearchPlaceChip> {
  static const _minQueryLength = 3;
  static const _debounce = Duration(milliseconds: 250);

  Timer? _debounceTimer;
  JPlaceResult? _topMatch;
  String _lastQuery = '';

  @override
  void didUpdateWidget(JobsSearchPlaceChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _schedule(widget.query);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _schedule(String raw) {
    _debounceTimer?.cancel();
    final query = raw.trim();
    if (query.length < _minQueryLength) {
      if (_topMatch != null) {
        setState(() {
          _topMatch = null;
          _lastQuery = query;
        });
      }
      return;
    }
    _debounceTimer = Timer(_debounce, () => unawaited(_resolve(query)));
  }

  Future<void> _resolve(String query) async {
    if (query == _lastQuery && _topMatch != null) return;
    try {
      final results = await ref.read(placesServiceProvider).autocomplete(query);
      if (!mounted) return;
      setState(() {
        _topMatch = results.isEmpty ? null : results.first;
        _lastQuery = query;
      });
    } on PlacesException {
      if (!mounted) return;
      setState(() {
        _topMatch = null;
        _lastQuery = query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = _topMatch;
    if (match == null) return const SizedBox.shrink();
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final upperSuburb = match.suburb.toUpperCase();
    final stateChip = match.state.isEmpty ? '' : ' ${match.state}';
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap(match);
            },
            borderRadius: BorderRadius.circular(2.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(2.r),
                border: Border.all(color: c.action, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.location, size: 14.r, color: c.action),
                  Gap(8.w),
                  Text(
                    'SUBURB: $upperSuburb$stateChip',
                    style: tt.labelMedium!.copyWith(
                      color: c.action,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
