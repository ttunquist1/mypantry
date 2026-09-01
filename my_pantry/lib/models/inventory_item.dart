class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.checked,
    required this.order,
    this.details = '',
    this.location = '',
    this.mealTags = const <String>[],
    this.recipeTags = const <String>[],
    this.fullnessPercent,
  });

  final String id;
  final String name;
  final String details;
  final String location;
  final List<String> mealTags;
  final List<String> recipeTags;
  final int? fullnessPercent;
  final bool checked;
  final int order;

  String get displayName => name.trim().isEmpty ? 'Untitled item' : name.trim();

  String get displayLabel {
    final trimmedDetails = details.trim();
    if (trimmedDetails.isEmpty) {
      return displayName;
    }
    return '$displayName - $trimmedDetails';
  }

  List<String> get summaryChips {
    final chips = <String>[];
    if (location.trim().isNotEmpty) {
      chips.add(location.trim());
    }
    chips.addAll(mealTags);
    return chips;
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? details,
    String? location,
    List<String>? mealTags,
    List<String>? recipeTags,
    int? fullnessPercent,
    bool clearFullnessPercent = false,
    bool? checked,
    int? order,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      location: location ?? this.location,
      mealTags: mealTags ?? this.mealTags,
      recipeTags: recipeTags ?? this.recipeTags,
      fullnessPercent:
          clearFullnessPercent ? null : fullnessPercent ?? this.fullnessPercent,
      checked: checked ?? this.checked,
      order: order ?? this.order,
    );
  }

  factory InventoryItem.fromMap(String id, Map<String, dynamic> map) {
    final rawMealTags = map['mealTags'];
    final rawRecipeTags = map['recipeTags'];
    final rawFullness = map['fullnessPercent'];
    final rawName = (map['name'] ?? map['item'] ?? '').toString();

    return InventoryItem(
      id: id,
      name: rawName,
      details: (map['details'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      mealTags: _coerceStringList(rawMealTags),
      recipeTags: _coerceStringList(rawRecipeTags),
      fullnessPercent: rawFullness is num ? rawFullness.toInt() : null,
      checked: map['checked'] == true,
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.trim(),
      'item': name.trim(),
      'details': details.trim(),
      'location': location.trim(),
      'mealTags': mealTags,
      'recipeTags': recipeTags,
      'fullnessPercent': fullnessPercent,
      'checked': checked,
      'order': order,
    };
  }

  static List<String> _coerceStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
