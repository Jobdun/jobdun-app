import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// Inbox search field (Phase D). Lives between the Messages header and the
/// list; the page owns the expand/collapse, this widget owns the text state
/// and the 200ms debounce before [onChanged] fires.
class InboxSearchBar extends StatefulWidget {
  const InboxSearchBar({
    super.key,
    required this.onChanged,
    required this.onClear,
  });

  /// Fired with the trimmed query after the debounce window.
  final ValueChanged<String> onChanged;

  /// Clear tapped: the page resets the query and collapses the bar.
  final VoidCallback onClear;

  @override
  State<InboxSearchBar> createState() => _InboxSearchBarState();
}

class _InboxSearchBarState extends State<InboxSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onText(String value) {
    setState(() {}); // refresh the trailing-clear visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      widget.onChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            Icon(AppIcons.search, size: AppIconSize.inline.r, color: c.text3),
            Gap(8.w),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onText,
                textInputAction: TextInputAction.search,
                style: tt.bodyMedium!.copyWith(color: c.text1),
                decoration: InputDecoration(
                  hintText: 'SEARCH MESSAGES',
                  hintStyle: tt.bodySmall!.copyWith(
                    color: c.text3,
                    letterSpacing: 0.6,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _debounce?.cancel();
                  _controller.clear();
                  widget.onClear();
                },
                child: Icon(
                  AppIcons.close,
                  size: AppIconSize.inline.r,
                  color: c.text3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
