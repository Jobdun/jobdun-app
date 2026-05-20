import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../data/models/trade_category_model.dart';
import '../providers/trade_categories_provider.dart';

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
  return showModalBottomSheet<TradeCategorySelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Grabber extends StatelessWidget {
  const _Grabber({required this.c});
  final JColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.c,
    required this.tt,
    required this.onClose,
  });

  final JColors c;
  final TextTheme tt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 4.h, 8.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PICK YOUR TRADE',
              style: tt.labelSmall!.copyWith(
                letterSpacing: 0.12 * 11,
                color: c.text1,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Iconsax.close_square, size: 20.r, color: c.text3),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.c,
    required this.tt,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 4.h, AppSpacing.lg.w, 12.h),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          border: Border.all(color: c.border),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          style: tt.bodyLarge!.copyWith(color: c.text1),
          decoration: InputDecoration(
            hintText: 'Search trades…',
            hintStyle: tt.bodyLarge!.copyWith(color: c.text3),
            prefixIcon: Icon(Iconsax.search_normal, size: 18.r, color: c.text3),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 12.h,
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.items,
    required this.selectedSlug,
    required this.onPick,
    required this.c,
    required this.tt,
  });

  final String title;
  final List<TradeCategory> items;
  final String? selectedSlug;
  final void Function(String slug) onPick;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 14.h, 0, 8.h),
          child: Text(
            title.toUpperCase(),
            style: tt.labelSmall!.copyWith(
              letterSpacing: 0.12 * 11,
              color: c.text3,
            ),
          ),
        ),
        ...items.map(
          (item) => _TradeRow(
            name: item.displayName,
            selected: selectedSlug == item.slug,
            onTap: () => onPick(item.slug),
            c: c,
            tt: tt,
          ),
        ),
      ],
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 14.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: tt.bodyLarge!.copyWith(
                    color: c.text1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(Iconsax.tick_circle, size: 20.r, color: c.action),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherSection extends StatelessWidget {
  const _OtherSection({
    required this.c,
    required this.tt,
    required this.isOpen,
    required this.controller,
    required this.onToggle,
    required this.onConfirm,
  });

  final JColors c;
  final TextTheme tt;
  final bool isOpen;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Iconsax.add_circle, size: 18.r, color: c.text2),
                Gap(10.w),
                Expanded(
                  child: Text(
                    'Other — not listed',
                    style: tt.bodyLarge!.copyWith(color: c.text1),
                  ),
                ),
                Icon(
                  isOpen ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                  size: 16.r,
                  color: c.text3,
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            Gap(12.h),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onConfirm(),
              style: tt.bodyLarge!.copyWith(color: c.text1),
              decoration: InputDecoration(
                hintText: 'e.g. Glazier, Stonemason',
                hintStyle: tt.bodyLarge!.copyWith(color: c.text3),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: c.background,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
                isDense: true,
              ),
            ),
            Gap(10.h),
            JButton(label: 'USE THIS TRADE', onPressed: onConfirm),
          ],
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.c,
    required this.tt,
    required this.query,
    required this.onTapOther,
  });

  final JColors c;
  final TextTheme tt;
  final String query;
  final VoidCallback onTapOther;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        24.h,
        AppSpacing.lg.w,
        24.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No matches for "$query".',
            style: tt.bodyLarge!.copyWith(color: c.text2),
          ),
          Gap(12.h),
          GestureDetector(
            onTap: onTapOther,
            child: Text(
              'Add it as "Other" →',
              style: tt.bodyLarge!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
