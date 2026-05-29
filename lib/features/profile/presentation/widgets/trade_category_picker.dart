import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../data/models/trade_category_model.dart';
import '../providers/trade_categories_provider.dart';

part 'trade_category_picker_widgets.dart';

// Returned from showTradeCategoryPicker — the caller stores both into
// trade_profiles.primary_trade and trade_profiles.trade_other (the latter only
// when slug == 'other').
class TradeCategorySelection {
  const TradeCategorySelection({required this.slug, this.otherText});
  final String slug;
  final String? otherText;
}

// Opens a search-first modal that fills most of the viewport. Returns the
// selection or null if dismissed.
Future<TradeCategorySelection?> showTradeCategoryPicker(
  BuildContext context, {
  String? initialSlug,
  String? initialOtherText,
}) {
  return showJSheet<TradeCategorySelection>(
    context: context,
    builder: (_) => _TradeCategoryPicker(
      initialSlug: initialSlug,
      initialOtherText: initialOtherText,
    ),
  );
}

class _TradeCategoryPicker extends ConsumerStatefulWidget {
  const _TradeCategoryPicker({this.initialSlug, this.initialOtherText});

  final String? initialSlug;
  final String? initialOtherText;

  @override
  ConsumerState<_TradeCategoryPicker> createState() =>
      _TradeCategoryPickerState();
}

class _TradeCategoryPickerState extends ConsumerState<_TradeCategoryPicker> {
  final _searchCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _query = '';
  String? _selectedSlug;
  bool _otherMode = false;

  @override
  void initState() {
    super.initState();
    _selectedSlug = widget.initialSlug;
    if (widget.initialOtherText != null) {
      _otherCtrl.text = widget.initialOtherText!;
      _otherMode = widget.initialSlug == 'other';
    }
    // Search-first: focus the input so the keyboard comes up immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _otherCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _submitSelection(String slug, [String? other]) {
    Navigator.of(
      context,
    ).pop(TradeCategorySelection(slug: slug, otherText: other));
  }

  void _confirmOther() {
    final text = _otherCtrl.text.trim();
    if (text.isEmpty) return;
    _submitSelection('other', text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final asyncCategories = ref.watch(tradeCategoriesProvider);

    return Padding(
      // Lift the sheet above the keyboard so the search field is never covered.
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card.r),
            ),
          ),
          child: Column(
            children: [
              _Grabber(c: c),
              _SheetHeader(c: c, tt: tt, onClose: () => Navigator.pop(context)),
              _SearchField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                c: c,
                tt: tt,
                onChanged: (v) => setState(() {
                  _query = v.trim().toLowerCase();
                  if (_query.isNotEmpty) _otherMode = false;
                }),
              ),
              Expanded(
                child: asyncCategories.when(
                  data: (rows) => _buildList(rows, c, tt),
                  loading: () => Center(
                    child: SizedBox.square(
                      dimension: 28.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.action,
                      ),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: EdgeInsets.all(20.r),
                    child: Text(
                      "Couldn't load trades. Check your connection.",
                      style: tt.bodyMedium!.copyWith(color: c.urgent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<TradeCategory> rows, JColors c, TextTheme tt) {
    // Filtered (flat) when search is active.
    if (_query.isNotEmpty) {
      final hits = rows
          .where((r) => r.displayName.toLowerCase().contains(_query))
          .toList(growable: false);
      if (hits.isEmpty) {
        return _EmptyHint(
          c: c,
          tt: tt,
          query: _query,
          onTapOther: () => setState(() {
            _otherMode = true;
            _searchFocus.unfocus();
          }),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w,
          8.h,
          AppSpacing.lg.w,
          24.h,
        ),
        itemCount: hits.length,
        itemBuilder: (_, i) => _TradeRow(
          name: hits[i].displayName,
          selected: _selectedSlug == hits[i].slug,
          onTap: () => _submitSelection(hits[i].slug),
          c: c,
          tt: tt,
        ),
      );
    }

    // Grouped + "Other" footer when search is empty.
    final byGroup = <TradeCategoryGroup, List<TradeCategory>>{};
    for (final r in rows) {
      byGroup.putIfAbsent(r.group, () => []).add(r);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 8.h, AppSpacing.lg.w, 24.h),
      children: [
        for (final group in TradeCategoryGroup.values)
          if (byGroup[group] != null)
            _GroupSection(
              title: group.label,
              items: byGroup[group]!,
              selectedSlug: _selectedSlug,
              onPick: _submitSelection,
              c: c,
              tt: tt,
            ),
        Gap(AppSpacing.md.h),
        _OtherSection(
          c: c,
          tt: tt,
          isOpen: _otherMode,
          controller: _otherCtrl,
          onToggle: () => setState(() {
            _otherMode = !_otherMode;
            if (_otherMode) _searchFocus.unfocus();
          }),
          onConfirm: _confirmOther,
        ),
      ],
    );
  }
}
