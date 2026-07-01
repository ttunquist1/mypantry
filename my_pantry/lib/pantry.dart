import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_pantry/models/inventory_item.dart';
import 'package:my_pantry/widgets/inventory_item_editor.dart';
import 'package:my_pantry/widgets/item_fullness_icon.dart';
import 'package:my_pantry/widgets/shared_users_list.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => PantryPageState();
}

class PantryPageState extends State<PantryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSubscription;

  List<Map<String, dynamic>> pantries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> shoppingLists = <Map<String, dynamic>>[];
  List<InventoryItem> items = <InventoryItem>[];
  String? selectedListId;
  String? selectedShoppingListId;

  String? get selectedListName {
    if (selectedListId == null) {
      return null;
    }
    final match = pantries.where((p) => p['id'] == selectedListId);
    if (match.isEmpty) {
      return null;
    }
    return (match.first['name'] ?? '').toString();
  }

  int get checkedItemCount => items.where((item) => item.checked).length;

  @override
  void initState() {
    super.initState();
    fetchPantries();
    fetchShoppingLists();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> createPantry(String name, List<String> userIds) async {
    if (name.trim().isEmpty || userIds.isEmpty) {
      _showMessage('Pantry name is required.', isError: true);
      return;
    }

    try {
      await _firestore.collection('Pantries').add(<String, dynamic>{
        'name': name.trim(),
        'sharedWith': userIds,
      });
      await fetchPantries();
    } catch (e) {
      _showMessage('Error creating pantry: $e', isError: true);
    }
  }

  Future<void> addUserToList(String listId, String userId) async {
    try {
      await _firestore.collection('Pantries').doc(listId).update(
        <String, dynamic>{
          'sharedWith': FieldValue.arrayUnion(<String>[userId]),
        },
      );
      await fetchPantries();
    } catch (e) {
      _showMessage('Error sharing pantry: $e', isError: true);
    }
  }

  Future<void> fetchShoppingLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection('shoppingLists')
              .where('sharedWith', arrayContains: user.uid)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        shoppingLists =
            snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList();
        if (shoppingLists.isNotEmpty && selectedShoppingListId == null) {
          selectedShoppingListId = shoppingLists.first['id']?.toString();
        }
      });
    } catch (e) {
      _showMessage('Error loading shopping lists: $e', isError: true);
    }
  }

  Future<void> fetchPantries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection('Pantries')
              .where('sharedWith', arrayContains: user.uid)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        pantries =
            snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList();
      });

      if (pantries.isEmpty) {
        await _itemsSubscription?.cancel();
        _itemsSubscription = null;
        if (!mounted) {
          return;
        }
        setState(() {
          selectedListId = null;
          items = <InventoryItem>[];
        });
        return;
      }

      final listStillExists = pantries.any((p) => p['id'] == selectedListId);
      if (!listStillExists) {
        final newId = pantries.first['id']?.toString();
        if (!mounted) {
          return;
        }
        setState(() {
          selectedListId = newId;
        });
        if (newId != null) {
          listenToItems(newId);
        }
      }
    } catch (e) {
      _showMessage('Error loading pantries: $e', isError: true);
    }
  }

  void listenToItems(String listId) {
    _itemsSubscription?.cancel();
    _itemsSubscription = _firestore
        .collection('Pantries')
        .doc(listId)
        .collection('items')
        .orderBy('order')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) {
              return;
            }
            setState(() {
              items = snapshot.docs
                  .map((doc) => InventoryItem.fromMap(doc.id, doc.data()))
                  .toList(growable: false);
            });
          },
          onError: (Object error) {
            if (mounted) {
              _showMessage('Error loading pantry items: $error', isError: true);
            }
          },
        );
  }

  void showCreatePantryDialog(String userId) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Pantry'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Pantry name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  createPantry(value, <String>[userId]);
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> openAddItemSheet() async {
    final listId = selectedListId;
    if (listId == null) {
      _showMessage('Create or select a pantry first.', isError: true);
      return;
    }

    final draft = await showInventoryItemEditor(
      context,
      title: 'Add Pantry Item',
    );
    if (draft == null) {
      return;
    }
    await addItemToList(listId, draft);
  }

  Future<void> addItemToList(String listId, InventoryItemDraft draft) async {
    try {
      final item = InventoryItem(
        id: '',
        name: draft.name,
        details: draft.details,
        location: draft.location,
        mealTags: draft.mealTags,
        recipeTags: draft.recipeTags,
        fullnessPercent: draft.fullnessPercent,
        checked: false,
        order: items.length,
      );

      await _firestore
          .collection('Pantries')
          .doc(listId)
          .collection('items')
          .add(item.toMap());
    } catch (e) {
      _showMessage('Error adding item: $e', isError: true);
    }
  }

  Future<void> editItem(InventoryItem item) async {
    final draft = await showInventoryItemEditor(
      context,
      title: 'Edit Pantry Item',
      initialItem: item,
    );
    if (draft == null || selectedListId == null) {
      return;
    }

    try {
      final updated = item.copyWith(
        name: draft.name,
        details: draft.details,
        location: draft.location,
        mealTags: draft.mealTags,
        recipeTags: draft.recipeTags,
        fullnessPercent: draft.fullnessPercent,
        clearFullnessPercent: draft.fullnessPercent == null,
      );

      await _firestore
          .collection('Pantries')
          .doc(selectedListId)
          .collection('items')
          .doc(item.id)
          .update(updated.toMap());
    } catch (e) {
      _showMessage('Error updating item: $e', isError: true);
    }
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    final listId = selectedListId;
    if (listId == null ||
        oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex > items.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final reordered = <InventoryItem>[...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      final batch = _firestore.batch();
      for (var i = 0; i < reordered.length; i++) {
        final item = reordered[i].copyWith(order: i);
        final docRef = _firestore
            .collection('Pantries')
            .doc(listId)
            .collection('items')
            .doc(item.id);
        batch.update(docRef, <String, dynamic>{'order': i});
      }
      await batch.commit();
    } catch (e) {
      _showMessage('Error reordering items: $e', isError: true);
    }
  }

  Future<void> showMoveToShoppingListDialog() async {
    if (shoppingLists.isEmpty) {
      _showMessage('No shopping lists available.', isError: true);
      return;
    }

    String? tempSelected =
        selectedShoppingListId ?? shoppingLists.first['id']?.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Move To Shopping List'),
              content: DropdownButton<String>(
                value: tempSelected,
                isExpanded: true,
                items:
                    shoppingLists.map((list) {
                      return DropdownMenuItem<String>(
                        value: list['id']?.toString(),
                        child: Text(
                          (list['name'] ?? 'Unnamed List').toString(),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    tempSelected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      tempSelected == null
                          ? null
                          : () async {
                            setState(() {
                              selectedShoppingListId = tempSelected;
                            });
                            Navigator.pop(dialogContext);
                            await moveCheckedToShoppingList();
                          },
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> moveCheckedToShoppingList() async {
    final pantryId = selectedListId;
    final shoppingListId = selectedShoppingListId;
    if (pantryId == null || shoppingListId == null) {
      return;
    }

    final checkedItems = items
        .where((item) => item.checked)
        .toList(growable: false);
    if (checkedItems.isEmpty) {
      _showMessage('Select items to move first.', isError: true);
      return;
    }

    try {
      final maxSnapshot =
          await _firestore
              .collection('shoppingLists')
              .doc(shoppingListId)
              .collection('items')
              .orderBy('order', descending: true)
              .limit(1)
              .get();

      var nextOrder = 0;
      if (maxSnapshot.docs.isNotEmpty) {
        final rawOrder = maxSnapshot.docs.first.data()['order'];
        if (rawOrder is num) {
          nextOrder = rawOrder.toInt() + 1;
        }
      }

      final batch = _firestore.batch();
      for (final item in checkedItems) {
        final shoppingItemRef =
            _firestore
                .collection('shoppingLists')
                .doc(shoppingListId)
                .collection('items')
                .doc();
        batch.set(
          shoppingItemRef,
          item.copyWith(checked: false, order: nextOrder).toMap(),
        );
        nextOrder += 1;

        final pantryItemRef = _firestore
            .collection('Pantries')
            .doc(pantryId)
            .collection('items')
            .doc(item.id);
        batch.delete(pantryItemRef);
      }

      await batch.commit();
      _showMessage('Moved ${checkedItems.length} item(s) to shopping list.');
    } catch (e) {
      _showMessage('Error moving items: $e', isError: true);
    }
  }

  Future<void> toggleCheck(InventoryItem item, bool newValue) async {
    final listId = selectedListId;
    if (listId == null) {
      return;
    }

    try {
      await _firestore
          .collection('Pantries')
          .doc(listId)
          .collection('items')
          .doc(item.id)
          .update(<String, dynamic>{'checked': newValue});
    } catch (e) {
      _showMessage('Error updating checkbox: $e', isError: true);
    }
  }

  Future<void> removeItemById(String listId, String itemId) async {
    try {
      await _firestore
          .collection('Pantries')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .delete();
    } catch (e) {
      _showMessage('Error deleting item: $e', isError: true);
    }
  }

  Future<void> showFriendShareDialog(
    BuildContext context,
    String listId,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _showMessage('You must be signed in to share lists.', isError: true);
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .get();
      final friendIds = List<String>.from(
        userDoc.data()?['friends'] ?? <String>[],
      );

      if (friendIds.isEmpty) {
        _showMessage('No friends found to share with.', isError: true);
        return;
      }

      final friendNameResults = await Future.wait(
        friendIds.map(
          (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
        ),
      );

      if (!context.mounted) {
        return;
      }

      final friendNames = <String, String>{};
      for (final doc in friendNameResults) {
        final id = doc.id;
        friendNames[id] = (doc.data()?['name'] ?? id).toString();
      }

      final selected = <String>{};

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Share Pantry'),
                content: SingleChildScrollView(
                  child: Column(
                    children:
                        friendIds.map((id) {
                          return CheckboxListTile(
                            value: selected.contains(id),
                            title: Text(friendNames[id] ?? id),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        selected.isEmpty
                            ? null
                            : () async {
                              for (final uid in selected) {
                                await addUserToList(listId, uid);
                              }
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              _showMessage(
                                'Pantry shared with ${selected.length} friend(s).',
                              );
                            },
                    child: const Text('Share'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      _showMessage('Error sharing pantry: $e', isError: true);
    }
  }

  Future<void> removePantry(String pantryId) async {
    try {
      final itemsSnapshot =
          await _firestore
              .collection('Pantries')
              .doc(pantryId)
              .collection('items')
              .get();

      final batch = _firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('Pantries').doc(pantryId));
      await batch.commit();
      await fetchPantries();
    } catch (e) {
      _showMessage('Error deleting pantry: $e', isError: true);
    }
  }

  Future<void> _sendSelectedIngredientsToRecipes() async {
    final selectedIngredients = items
        .where((item) => item.checked)
        .map((item) => item.displayLabel)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (selectedIngredients.isEmpty) {
      _showMessage('Select ingredients to send first.', isError: true);
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamed(context, '/ai', arguments: selectedIngredients);
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    super.dispose();
  }

  Widget _buildItemCard(InventoryItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        if (selectedListId != null) {
          removeItemById(selectedListId!, item.id);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          onTap: () => editItem(item),
          leading: Checkbox(
            value: item.checked,
            onChanged: (value) => toggleCheck(item, value ?? false),
          ),
          title: Text(
            item.displayName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: item.checked ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.details.trim().isNotEmpty) Text(item.details.trim()),
                if (item.summaryChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.summaryChips
                        .map((chip) => Chip(label: Text(chip)))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemFullnessIcon(fullnessPercent: item.fullnessPercent),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userId) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pantry', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Keep items readable, detailed, and easy to move.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (pantries.isEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showCreatePantryDialog(userId),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Your First Pantry'),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selectedListId,
                decoration: const InputDecoration(
                  labelText: 'Current pantry',
                  border: OutlineInputBorder(),
                ),
                items: pantries
                    .map((list) {
                      return DropdownMenuItem<String>(
                        value: list['id']?.toString(),
                        child: Text(
                          (list['name'] ?? 'Unnamed Pantry').toString(),
                        ),
                      );
                    })
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    selectedListId = value;
                  });
                  if (value != null) {
                    listenToItems(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: openAddItemSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showCreatePantryDialog(userId),
                    icon: const Icon(Icons.kitchen_outlined),
                    label: const Text('New Pantry'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        selectedListId == null
                            ? null
                            : () =>
                                showFriendShareDialog(context, selectedListId!),
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Share'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        selectedListId == null
                            ? null
                            : () => removePantry(selectedListId!),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed:
                checkedItemCount == 0 ? null : showMoveToShoppingListDialog,
            icon: const Icon(Icons.shopping_cart_checkout_outlined),
            label: Text('Move Checked ($checkedItemCount)'),
          ),
          OutlinedButton.icon(
            onPressed:
                checkedItemCount == 0
                    ? null
                    : _sendSelectedIngredientsToRecipes,
            icon: const Icon(Icons.restaurant_menu_outlined),
            label: const Text('Send To Recipes'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'No pantry items yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add simple names now, then enrich them with details like size, brand, and kitchen location.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: openAddItemSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add First Item'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return Column(
      children: [
        _buildHeader(userId),
        if (selectedListId != null) _buildActionBar(),
        if (selectedListId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SharedUsersList(
                listId: selectedListId!,
                collection: 'Pantries',
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child:
              selectedListId == null
                  ? const SizedBox.shrink()
                  : items.isEmpty
                  ? _buildEmptyItemsState()
                  : ReorderableListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    onReorder: reorderItems,
                    children: items
                        .map((item) => _buildItemCard(item))
                        .toList(growable: false),
                  ),
        ),
      ],
    );
  }
}
