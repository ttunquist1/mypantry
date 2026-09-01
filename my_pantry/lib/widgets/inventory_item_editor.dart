import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

class InventoryItemDraft {
  const InventoryItemDraft({
    required this.name,
    this.details = '',
    this.location = '',
    this.mealTags = const <String>[],
    this.recipeTags = const <String>[],
    this.fullnessPercent,
  });

  final String name;
  final String details;
  final String location;
  final List<String> mealTags;
  final List<String> recipeTags;
  final int? fullnessPercent;
}

Future<InventoryItemDraft?> showInventoryItemEditor(
  BuildContext context, {
  InventoryItem? initialItem,
  required String title,
}) {
  final nameController = TextEditingController(text: initialItem?.name ?? '');
  final detailsController = TextEditingController(
    text: initialItem?.details ?? '',
  );
  final locationController = TextEditingController(
    text: initialItem?.location ?? '',
  );
  final mealTagsController = TextEditingController(
    text: initialItem?.mealTags.join(', '),
  );
  final recipeTagsController = TextEditingController(
    text: initialItem?.recipeTags.join(', '),
  );

  return showModalBottomSheet<InventoryItemDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      double fullnessValue = (initialItem?.fullnessPercent ?? 100).toDouble();
      bool trackFullness = initialItem?.fullnessPercent != null;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Eggs',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: '12 large AA eggs',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kitchen location',
                      hintText: 'Fridge door',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mealTagsController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Meals',
                      hintText: 'Breakfast, Snack',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recipeTagsController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Recipes',
                      hintText: 'Omelet, Pancakes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Track amount left'),
                    subtitle: const Text(
                      'Used later for progress icons and alerts',
                    ),
                    value: trackFullness,
                    onChanged: (value) {
                      setSheetState(() {
                        trackFullness = value;
                      });
                    },
                  ),
                  if (trackFullness) ...[
                    Text('Amount left: ${fullnessValue.round()}%'),
                    Slider(
                      value: fullnessValue,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${fullnessValue.round()}%',
                      onChanged: (value) {
                        setSheetState(() {
                          fullnessValue = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          return;
                        }
                        Navigator.pop(
                          context,
                          InventoryItemDraft(
                            name: name,
                            details: detailsController.text.trim(),
                            location: locationController.text.trim(),
                            mealTags: _splitTags(mealTagsController.text),
                            recipeTags: _splitTags(recipeTagsController.text),
                            fullnessPercent:
                                trackFullness ? fullnessValue.round() : null,
                          ),
                        );
                      },
                      child: Text(
                        initialItem == null ? 'Add Item' : 'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    detailsController.dispose();
    locationController.dispose();
    mealTagsController.dispose();
    recipeTagsController.dispose();
  });
}

List<String> _splitTags(String input) {
  return input
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
