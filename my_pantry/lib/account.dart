import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_pantry/qrcode.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<String?> _getUsername(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['name']?.toString();
  }

  Future<String?> _getFriendCode(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['friendCode']?.toString();
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> sendFriendRequest(
    BuildContext context,
    String friendCode,
  ) async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null || friendCode.trim().isEmpty) {
      return;
    }

    try {
      final result =
          await FirebaseFirestore.instance
              .collection('users')
              .where('friendCode', isEqualTo: friendCode.trim())
              .limit(1)
              .get();

      if (!context.mounted) {
        return;
      }

      if (result.docs.isEmpty) {
        _showMessage(context, 'Friend code not found.', isError: true);
        return;
      }

      final friendId = result.docs.first.id;
      if (friendId == myId) {
        _showMessage(context, "You can't friend yourself.", isError: true);
        return;
      }

      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('friendRequests')
          .doc(myId);

      await requestRef.set(<String, dynamic>{
        'from': myId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        _showMessage(context, 'Friend request sent!');
      }
    } catch (e) {
      if (context.mounted) {
        _showMessage(
          context,
          'Unable to send friend request: $e',
          isError: true,
        );
      }
    }
  }

  void _showChangeEmailDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'New Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final currentEmail = user?.email;
                final newEmail = emailController.text.trim();
                final password = passwordController.text;

                if (user == null ||
                    currentEmail == null ||
                    newEmail.isEmpty ||
                    password.isEmpty) {
                  _showMessage(
                    context,
                    'All fields are required.',
                    isError: true,
                  );
                  return;
                }

                try {
                  final cred = EmailAuthProvider.credential(
                    email: currentEmail,
                    password: password,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.verifyBeforeUpdateEmail(newEmail);

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update(<String, dynamic>{'email': newEmail});

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (context.mounted) {
                    _showMessage(
                      context,
                      'Verification email sent to update your address.',
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (context.mounted) {
                    _showMessage(context, 'Error: $e', isError: true);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      emailController.dispose();
      passwordController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user signed in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: FutureBuilder<String?>(
        future: _getUsername(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final username = snapshot.data ?? 'Not set';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: $username'),
                const SizedBox(height: 10),
                Text('Email: ${user.email ?? 'Not set'}'),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/sign_in',
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('Sign Out'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final activeUser = FirebaseAuth.instance.currentUser;
                    final email = activeUser?.email;
                    if (email == null) {
                      _showMessage(
                        context,
                        'Unable to send reset email.',
                        isError: true,
                      );
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: email,
                      );
                      if (context.mounted) {
                        _showMessage(context, 'Password reset email sent.');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showMessage(
                          context,
                          'Unable to send reset email: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: const Text('Change Password'),
                ),
                ElevatedButton(
                  onPressed: () => _showChangeEmailDialog(context),
                  child: const Text('Change Email'),
                ),
                FutureBuilder<String?>(
                  future: _getFriendCode(user.uid),
                  builder: (context, codeSnapshot) {
                    if (codeSnapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }

                    final friendCode = codeSnapshot.data ?? 'Unavailable';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        const Text('Your Friend Code:'),
                        SelectableText(
                          friendCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: QrImageView(
                            data: friendCode,
                            version: QrVersions.auto,
                            size: 150,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final scannedCode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QRScannerPage(),
                              ),
                            );

                            if (!context.mounted) {
                              return;
                            }
                            if (scannedCode != null && scannedCode.isNotEmpty) {
                              await sendFriendRequest(context, scannedCode);
                            }
                          },
                          child: const Text("Scan Friend's QR Code"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final controller = TextEditingController();
                            showDialog<void>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Enter Friend Code'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Friend Code',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(dialogContext),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final inputCode =
                                            controller.text.trim();
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        await sendFriendRequest(
                                          context,
                                          inputCode,
                                        );
                                      },
                                      child: const Text('Add Friend'),
                                    ),
                                  ],
                                );
                              },
                            ).whenComplete(controller.dispose);
                          },
                          child: const Text('Add Friend Manually'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
