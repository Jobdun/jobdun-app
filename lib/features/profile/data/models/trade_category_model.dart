import 'package:equatable/equatable.dart';

// Reference data — rows in public.trade_categories. Read-only on the client.
// Groups drive the section headers in TradeCategoryPicker.
enum TradeCategoryGroup {
  electrical,
  structural,
  finishing,
  heavySpecialist;

  static TradeCategoryGroup fromDb(String value) => switch (value) {
    'electrical' => TradeCategoryGroup.electrical,
    'structural' => TradeCategoryGroup.structural,
    'finishing' => TradeCategoryGroup.finishing,
    'heavy_specialist' => TradeCategoryGroup.heavySpecialist,
    _ => TradeCategoryGroup.structural,
  };

  String get label => switch (this) {
    TradeCategoryGroup.electrical => 'Electrical',
    TradeCategoryGroup.structural => 'Structural',
    TradeCategoryGroup.finishing => 'Finishing',
    TradeCategoryGroup.heavySpecialist => 'Heavy / Specialist',
  };
}

class TradeCategory extends Equatable {
  const TradeCategory({
    required this.slug,
    required this.displayName,
    required this.group,
    required this.sortOrder,
  });

  factory TradeCategory.fromJson(Map<String, dynamic> json) => TradeCategory(
    slug: json['slug'] as String,
    displayName: json['display_name'] as String,
    group: TradeCategoryGroup.fromDb(json['category'] as String),
    sortOrder: (json['sort_order'] as int?) ?? 0,
  );

  final String slug;
  final String displayName;
  final TradeCategoryGroup group;
  final int sortOrder;

  @override
  List<Object?> get props => [slug, displayName, group, sortOrder];
}
