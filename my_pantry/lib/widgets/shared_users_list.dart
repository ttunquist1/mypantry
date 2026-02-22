import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SharedUsersList extends StatelessWidget {
  const SharedUsersList({
    super.key,
    required this.listId,
    this.collection = 'shoppingLists',
  });

  final String listId;
  final String collection;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(listId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error loading shared users: ${snapshot.error}');
        }

        final data = snapshot.data?.data();
        final sharedUids = List<String>.from(data?['sharedWith'] ?? <String>[]);

        if (sharedUids.isEmpty) {
          return const Text('Not shared with anyone yet.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Shared With:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            ...sharedUids.map((uid) {
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text('Loading...'));
                  }

                  final userData = userSnapshot.data?.data();
                  final name = (userData?['name'] ?? uid).toString();

                  return ListTile(
                    dense: true,
                    title: Text(name),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Remove Access?'),
                              content: Text('Remove "$name" from shared list?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true) {
                          return;
                        }

                        try {
                          await FirebaseFirestore.instance
                              .collection(collection)
                              .doc(listId)
                              .update(<String, dynamic>{
                            'sharedWith': FieldValue.arrayRemove(<String>[uid]),
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name removed from shared list.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to remove user: $e'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}
