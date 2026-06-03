import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/tradie_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';
import '../providers/discovery_provider.dart';
import '../widgets/discovery_tradie_tile.dart';
import '../widgets/trade_filter_sheet.dart';

part 'discovery_page_widgets.dart';

/// Full trade-directory search: paginated geo + rating + availability results.
/// Origin resolves from the builder's service location → device GPS → a
/// sensible AU fallback so the page never sits dead with no point to measure
/// distance from.
class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  // Sydney CBD — last-resort origin if profile + GPS both fail.
  static const _fallbackLat = -33.8688;
  static const _fallbackLng = 151.2093;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolveOriginThenLoad();
    });
  }

  Future<void> _resolveOriginThenLoad() async {
    final (lat, lng) = await _resolveOrigin();
    if (!mounted) return;
    await ref.read(tradeSearchControllerProvider.notifier).setOrigin(lat, lng);
    if (mounted) setState(() => _ready = true);
  }

  Future<(double, double)> _resolveOrigin() async {
    final bp = ref.read(profileControllerProvider).builderProfile;
    if (bp?.serviceLatitude != null && bp?.serviceLongitude != null) {
      return (bp!.serviceLatitude!, bp.serviceLongitude!);
    }
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition();
          return (pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // fall through to the AU default
    }
    return (_fallbackLat, _fallbackLng);
  }

  Future<void> _openFilters() async {
    final current = ref.read(tradeSearchControllerProvider).filter;
    final updated = await showJSheet<TradeSearchFilter>(
      context: context,
      builder: (_) => TradeFilterSheet(initial: current),
    );
    if (updated != null) {
      await ref
          .read(tradeSearchControllerProvider.notifier)
          .updateFilter(updated);
    }
  }

  void _clearFilters() {
    final f = ref.read(tradeSearchControllerProvider).filter;
    ref
        .read(tradeSearchControllerProvider.notifier)
        .updateFilter(
          TradeSearchFilter(originLat: f.originLat, originLng: f.originLng),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final pagingController = ref
        .read(tradeSearchControllerProvider.notifier)
        .pagingController;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'FIND A TRADIE',
          style: tt.titleLarge!.copyWith(color: c.text1),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: Icon(
              AppIcons.filter,
              size: AppIconSize.inline.r,
              color: c.text1,
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: SafeArea(
        child: !_ready
            ? const _DiscoverySkeleton()
            : RefreshIndicator(
                color: c.action,
                backgroundColor: c.surface,
                onRefresh: () async => pagingController.refresh(),
                child: PagedListView<int, TradeSearchResult>.separated(
                  pagingController: pagingController,
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    AppSpacing.sm.h,
                    20.w,
                    AppSpacing.lg.h,
                  ),
                  separatorBuilder: (_, _) => Gap(9.h),
                  builderDelegate: PagedChildBuilderDelegate<TradeSearchResult>(
                    itemBuilder: (context, result, i) =>
                        DiscoveryTradieTile(result: result, onTap: () {}),
                    firstPageProgressIndicatorBuilder: (_) =>
                        const _DiscoverySkeleton(),
                    newPageProgressIndicatorBuilder: (_) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: SizedBox(
                          width: 22.r,
                          height: 22.r,
                          child: CircularProgressIndicator(
                            color: c.action,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    noItemsFoundIndicatorBuilder: (_) =>
                        _DiscoveryEmpty(onClear: _clearFilters),
                    firstPageErrorIndicatorBuilder: (_) => _DiscoveryError(
                      message:
                          pagingController.error?.toString() ??
                          "Couldn't load tradies. Tap to try again.",
                      onRetry: () => pagingController.refresh(),
                    ),
                    newPageErrorIndicatorBuilder: (_) => _DiscoveryError(
                      message:
                          pagingController.error?.toString() ??
                          "Couldn't load tradies. Tap to try again.",
                      onRetry: () => pagingController.retryLastFailedRequest(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
