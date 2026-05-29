part of 'trade_category_picker.dart';

// Private leaf widgets for the trade-category picker, split into a `part` so
// `trade_category_picker.dart` stays under the file-size budget. They remain
// private, single-use helpers co-located with their only caller (the picker
// state) — moving them here changes nothing but the byte offset.

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
            icon: Icon(AppIcons.closeBox, size: 20.r, color: c.text3),
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
            prefixIcon: Icon(AppIcons.search, size: 18.r, color: c.text3),
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
                Icon(AppIcons.successCircle, size: 20.r, color: c.action),
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
                Icon(AppIcons.addCircle, size: 18.r, color: c.text2),
                Gap(10.w),
                Expanded(
                  child: Text(
                    'Other — not listed',
                    style: tt.bodyLarge!.copyWith(color: c.text1),
                  ),
                ),
                Icon(
                  isOpen ? AppIcons.chevronUp : AppIcons.chevronDown,
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
