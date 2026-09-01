import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_pantry/widgets/appdrawer.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final friendCodeController = TextEditingController();
  String? currentUid;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    friendCodeController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> declineFriendRequest(String requesterId) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friendRequests')
          .doc(requesterId)
          .delete();
    } catch (e) {
      _showMessage('Unable to decline request: $e', isError: true);
    }
  }

  Future<void> removeFriend(String friendId) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final myRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final theirRef = FirebaseFirestore.instance
          .collection('users')
          .doc(friendId);

      batch.update(myRef, <String, dynamic>{
        'friends': FieldValue.arrayRemove(<String>[friendId]),
      });
      batch.update(theirRef, <String, dynamic>{
        'friends': FieldValue.arrayRemove(<String>[uid]),
      });

      await batch.commit();
    } catch (e) {
      _showMessage('Unable to remove friend: $e', isError: true);
    }
  }

  Future<String> _getFriendName(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (doc.data()?['name'] ?? uid).toString();
  }

  Future<void> sendFriendRequest(String friendCode) async {
    final uid = currentUid;
    if (friendCode.trim().isEmpty || uid == null) {
      return;
    }

    try {
      final result =
          await FirebaseFirestore.instance
              .collection('users')
              .where('friendCode', isEqualTo: friendCode.trim())
              .limit(1)
              .get();

      if (result.docs.isEmpty) {
        _showMessage('Friend code not found.', isError: true);
        return;
      }

      final friendId = result.docs.first.id;
      if (friendId == uid) {
        _showMessage("You can't friend yourself.", isError: true);
        return;
      }

      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('friendRequests')
          .doc(uid);

      await requestRef.set(<String, dynamic>{
        'from': uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showMessage('Friend request sent!');
      friendCodeController.clear();
    } catch (e) {
      _showMessage('Unable to send request: $e', isError: true);
    }
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final myDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final friendDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(requesterId);
      final requestDoc = myDoc.collection('friendRequests').doc(requesterId);

      batch.update(myDoc, <String, dynamic>{
        'friends': FieldValue.arrayUnion(<String>[requesterId]),
      });
      batch.update(friendDoc, <String, dynamic>{
        'friends': FieldValue.arrayUnion(<String>[uid]),
      });
      batch.delete(requestDoc);

      await batch.commit();
    } catch (e) {
      _showMessage('Unable to accept request: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Friends & Requests')),
      endDrawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Friend Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('friendRequests')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final requests = snapshot.data!.docs;

                if (requests.isEmpty) {
                  return const Text('No friend requests');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final requesterId = requests[index].id;
                    return FutureBuilder<String>(
                      future: _getFriendName(requesterId),
                      builder: (context, nameSnapshot) {
                        final name = nameSnapshot.data ?? requesterId;
                        return ListTile(
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    () => acceptFriendRequest(requesterId),
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed:
                                    () => declineFriendRequest(requesterId),
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final friendIds = List<String>.from(
                  snapshot.data!.data()?['friends'] ?? <String>[],
                );
                if (friendIds.isEmpty) {
                  return const Text('No friends yet');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friendIds.length,
                  itemBuilder: (context, index) {
                    final friendId = friendIds[index];
                    return FutureBuilder<String>(
                      future: _getFriendName(friendId),
                      builder: (context, nameSnapshot) {
                        final name = nameSnapshot.data ?? friendId;
                        return ListTile(
                          title: Text(name),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => removeFriend(friendId),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Send a Friend Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: friendCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Friend Code',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => sendFriendRequest(friendCodeController.text),
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
