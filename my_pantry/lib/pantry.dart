import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_pantry/widgets/shared_users_list.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => PantryPageState();
}

class PantryPageState extends State<PantryPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _ghostController = TextEditingController();
  final FocusNode _ghostFocusNode = FocusNode();
  final Map<String, TextEditingController> controllerMap =
      <String, TextEditingController>{};

  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSubscription;

  List<Map<String, dynamic>> pantries = <Map<String, dynamic>>[];
  String? selectedListId;
  List<Map<String, dynamic>> shoppingLists = <Map<String, dynamic>>[];
  String? selectedShoppingListId;
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

  String? get selectedListName {
    if (selectedListId == null) {
      return null;
    }
    final match = pantries.where((p) => p['id'] == selectedListId);
    if (match.isEmpty) {
      return '';
    }
    return (match.first['name'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

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
      await _firestore.collection('Pantries').doc(listId).update(<String, dynamic>{
        'sharedWith': FieldValue.arrayUnion(<String>[userId]),
      });
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
      final snapshot = await _firestore
          .collection('shoppingLists')
          .where('sharedWith', arrayContains: user.uid)
          .get();

      if (!mounted) {
        return;
      }
      setState(() {
        shoppingLists =
            snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();
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
      final snapshot = await _firestore
          .collection('Pantries')
          .where('sharedWith', arrayContains: user.uid)
          .get();

      if (!mounted) {
        return;
      }
      setState(() {
        pantries =
            snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();
      });

      if (pantries.isNotEmpty) {
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
      } else {
        _itemsSubscription?.cancel();
        _itemsSubscription = null;
        if (!mounted) {
          return;
        }
        setState(() {
          selectedListId = null;
          items = <Map<String, dynamic>>[];
        });
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
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList();

          for (final item in items) {
            final id = item['id']?.toString();
            if (id == null) {
              continue;
            }
            final text = item['item']?.toString() ?? '';
            final existing = controllerMap[id];

            if (existing == null) {
              controllerMap[id] = TextEditingController(text: text);
              continue;
            }

            if (existing.text != text && existing.selection.isCollapsed) {
              final oldSelection = existing.selection;
              existing.text = text;
              existing.selection = oldSelection;
            }
          }

          final validIds = items.map((item) => item['id']?.toString()).toSet();
          final staleIds = controllerMap.keys
              .where((id) => !validIds.contains(id))
              .toList(growable: false);
          for (final staleId in staleIds) {
            controllerMap.remove(staleId)?.dispose();
          }
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
            TextButton(
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

    final reordered = <Map<String, dynamic>>[...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      final batch = _firestore.batch();
      for (var i = 0; i < reordered.length; i++) {
        final itemId = reordered[i]['id']?.toString();
        if (itemId == null) {
          continue;
        }
        final docRef = _firestore
            .collection('Pantries')
            .doc(listId)
            .collection('items')
            .doc(itemId);
        batch.update(docRef, <String, dynamic>{'order': i});
      }
      await batch.commit();
    } catch (e) {
      _showMessage('Error reordering items: $e', isError: true);
    }
  }

  Future<void> addItemToList(String listId, String itemName) async {
    final value = itemName.trim();
    if (value.isEmpty) {
      return;
    }
    try {
      await _firestore.collection('Pantries').doc(listId).collection('items').add(
        <String, dynamic>{
          'item': value,
          'checked': false,
          'order': items.length,
        },
      );
    } catch (e) {
      _showMessage('Error adding item: $e', isError: true);
    }
  }

  Future<void> showMoveToShoppingListDialog() async {
    if (shoppingLists.isEmpty) {
      _showMessage('No shopping lists available.', isError: true);
      return;
    }

    String? tempSelected = selectedShoppingListId ?? shoppingLists.first['id']?.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Select Shopping List'),
              content: DropdownButton<String>(
                value: tempSelected,
                isExpanded: true,
                items: shoppingLists.map((list) {
                  return DropdownMenuItem<String>(
                    value: list['id']?.toString(),
                    child: Text((list['name'] ?? 'Unnamed List').toString()),
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
                ElevatedButton(
                  onPressed: tempSelected == null
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

    final checkedItems =
        items.where((item) => item['checked'] == true).toList(growable: false);
    if (checkedItems.isEmpty) {
      _showMessage('No checked items to move.', isError: true);
      return;
    }

    try {
      final maxSnapshot = await _firestore
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
        final itemId = item['id']?.toString();
        if (itemId == null) {
          continue;
        }

        final shoppingItemRef = _firestore
            .collection('shoppingLists')
            .doc(shoppingListId)
            .collection('items')
            .doc();
        batch.set(shoppingItemRef, <String, dynamic>{
          'item': item['item']?.toString() ?? '',
          'checked': false,
          'order': nextOrder,
        });
        nextOrder += 1;

        final pantryItemRef = _firestore
            .collection('Pantries')
            .doc(pantryId)
            .collection('items')
            .doc(itemId);
        batch.delete(pantryItemRef);
      }

      await batch.commit();
      _showMessage('Moved ${checkedItems.length} item(s) to shopping list.');
    } catch (e) {
      _showMessage('Error moving items: $e', isError: true);
    }
  }

  Future<void> updateItem(String listId, int index, String newText) async {
    if (index < 0 || index >= items.length) {
      return;
    }
    final id = items[index]['id']?.toString();
    if (id == null) {
      return;
    }

    try {
      await _firestore
          .collection('Pantries')
          .doc(listId)
          .collection('items')
          .doc(id)
          .update(<String, dynamic>{'item': newText});
      if (!mounted) {
        return;
      }
      setState(() {
        items[index]['item'] = newText;
      });
    } catch (e) {
      _showMessage('Error updating item: $e', isError: true);
    }
  }

  Future<void> toggleCheck(String listId, int index) async {
    if (index < 0 || index >= items.length) {
      return;
    }
    final id = items[index]['id']?.toString();
    if (id == null) {
      return;
    }

    final current = items[index]['checked'] == true;
    final newValue = !current;
    try {
      await _firestore
          .collection('Pantries')
          .doc(listId)
          .collection('items')
          .doc(id)
          .update(<String, dynamic>{'checked': newValue});
      if (!mounted) {
        return;
      }
      setState(() {
        items[index]['checked'] = newValue;
      });
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

      if (mounted) {
        setState(() {
          final index = items.indexWhere((item) => item['id'] == itemId);
          if (index != -1) {
            items.removeAt(index);
            controllerMap.remove(itemId)?.dispose();
          }
        });
      }

      _rotationController.repeat(period: const Duration(milliseconds: 600));
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _rotationController.stop();
        }
      });
    } catch (e) {
      _showMessage('Error deleting item: $e', isError: true);
    }
  }

  Future<void> showFriendShareDialog(BuildContext context, String listId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _showMessage('You must be signed in to share lists.', isError: true);
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? <String>[]);

      if (friendIds.isEmpty) {
        _showMessage('No friends found to share with.', isError: true);
        return;
      }

      final friendNameResults = await Future.wait(
        friendIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get()),
      );

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
                title: const Text('Share List With Friends'),
                content: SingleChildScrollView(
                  child: Column(
                    children: friendIds.map((id) {
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
                  ElevatedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            for (final uid in selected) {
                              await addUserToList(listId, uid);
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _showMessage(
                              'List shared with ${selected.length} friend(s).',
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
      _showMessage('Error sharing list: $e', isError: true);
    }
  }

  Future<void> removePantry(String pantryId) async {
    try {
      final itemsSnapshot =
          await _firestore.collection('Pantries').doc(pantryId).collection('items').get();

      final batch = _firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('Pantries').doc(pantryId));
      await batch.commit();

      if (selectedListId == pantryId && mounted) {
        setState(() {
          selectedListId = null;
          items = <Map<String, dynamic>>[];
        });
      }
      await fetchPantries();
    } catch (e) {
      _showMessage('Error deleting pantry: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _rotationController.dispose();
    _ghostController.dispose();
    _ghostFocusNode.dispose();
    for (final controller in controllerMap.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget buildItem(int index, {required Key key}) {
    final item = items[index];
    final itemId = item['id']?.toString();
    if (itemId == null) {
      return const SizedBox.shrink();
    }

    final controller = controllerMap[itemId];
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: RotationTransition(
          turns: _rotationAnimation,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
      onDismissed: (_) {
        if (selectedListId != null) {
          removeItemById(selectedListId!, itemId);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ListTile(
          leading: Checkbox(
            value: item['checked'] == true,
            onChanged: (_) {
              if (selectedListId != null) {
                toggleCheck(selectedListId!, index);
              }
            },
          ),
          title: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Item',
            ),
            onChanged: (value) {
              if (selectedListId != null) {
                updateItem(selectedListId!, index, value);
              }
            },
          ),
          trailing: const Icon(Icons.drag_handle),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: const Text('Manage Pantry'),
              initiallyExpanded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: selectedListId,
                              hint: const Text('Select a pantry'),
                              isExpanded: true,
                              items: pantries.map((list) {
                                return DropdownMenuItem<String>(
                                  value: list['id']?.toString(),
                                  child: Text((list['name'] ?? 'Unnamed List').toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedListId = value;
                                });
                                if (value != null) {
                                  listenToItems(value);
                                }
                              },
                            ),
                          ),
                          if (selectedListId != null)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Pantry',
                              onPressed: () => removePantry(selectedListId!),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => showCreatePantryDialog(userId),
                              child: const Text('Create New Pantry'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (selectedListId != null)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    showFriendShareDialog(context, selectedListId!),
                                child: const Text('Share This List'),
                              ),
                            ),
                        ],
                      ),
                      if (selectedListId != null) ...[
                        const SizedBox(height: 8),
                        SharedUsersList(
                          listId: selectedListId!,
                          collection: 'Pantries',
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selectedListId != null && selectedShoppingListId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Add Checked Items to Shopping List'),
              onPressed: () async {
                final checkedItems =
                    items.where((item) => item['checked'] == true).toList();
                if (checkedItems.isEmpty) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('Nothing selected'),
                      content: Text('Please check items to move to the shopping list.'),
                    ),
                  );
                  return;
                }
                await showMoveToShoppingListDialog();
              },
            ),
          ),
        const Divider(),
        if (selectedListId != null)
          Expanded(
            child: ReorderableListView(
              onReorder: reorderItems,
              children: [
                for (var index = 0; index < items.length; index++)
                  buildItem(index, key: ValueKey(items[index]['id'])),
              ],
            ),
          ),
        if (selectedListId != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ghostController,
                  focusNode: _ghostFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Add item...',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && selectedListId != null) {
                      addItemToList(selectedListId!, value.trim());
                      _ghostController.clear();
                    }
                    FocusScope.of(context).requestFocus(_ghostFocusNode);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final selectedIngredients = items
                        .where((item) => item['checked'] == true)
                        .map<String>((item) => item['item']?.toString() ?? '')
                        .where((value) => value.isNotEmpty)
                        .toList();

                    if (selectedIngredients.isEmpty) {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => const AlertDialog(
                          title: Text('Nothing selected'),
                          content: Text('Please check ingredients to send.'),
                        ),
                      );
                      return;
                    }

                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pushNamed(
                      context,
                      '/ai',
                      arguments: selectedIngredients,
                    );
                  },
                  child: const Text('Send Selected Ingredients'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
