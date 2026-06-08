import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:jobdun/features/discovery/presentation/widgets/trade_map_preview.dart';

// Default-state fake so the widget doesn't reach searchTradesUseCaseProvider
// (which would touch Supabase). Empty results + default filter is all the
// preview reads.
class _FakeTradeSearch extends TradeSearchController {
  @override
  TradeSearchState build() => const TradeSearchState();
}

void main() {
  // Regression: TradeMapPreview wrapped its card in a Material that set BOTH
  // `shape` and `borderRadius`, which Flutter forbids — the builder home map
  // threw "Failed assertion: !(shape != null && borderRadius != null)" on every
  // build and rendered the red error box instead of the map.
  testWidgets('TradeMapPreview builds without throwing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradeSearchControllerProvider.overrideWith(_FakeTradeSearch.new),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: TradeMapPreview()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
