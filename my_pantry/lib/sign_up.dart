import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _signUp() async {
    if (_isSubmitting) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Name, email, and password are required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCred.user;
      if (user == null) {
        throw StateError('Account was created without a user session.');
      }

      await user.updateDisplayName(name);
      await user.reload();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'friends': <String>[],
        'pantrySharingWith': <String>[],
        'friendCode':
            user.uid.length >= 6 ? user.uid.substring(0, 6) : user.uid,
      });

      if (!mounted) {
        return;
      }

      _showMessage('Sign up successful!');
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/homepager',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Unable to sign up.');
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              autofillHints: const [AutofillHints.name],
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              autofillHints: const [AutofillHints.email],
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              autofillHints: const [AutofillHints.newPassword],
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _signUp,
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Sign Up'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/sign_in');
              },
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
