import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigateToPage(BuildContext context, int page) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/homepager',
      (route) => false,
      arguments: {'initialPage': page},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const SizedBox.shrink(),
          ),
          ListTile(
            title: const Text('Pantry'),
            onTap: () => _navigateToPage(context, 0),
          ),
          ListTile(
            title: const Text('Shopping List'),
            onTap: () => _navigateToPage(context, 1),
          ),
          ListTile(
            title: const Text('Recipes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(
                context,
                '/ai',
                arguments: const <String>[],
              );
            },
          ),
          ListTile(
            title: const Text('Friends'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/friends');
            },
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
          ListTile(
            title: const Text('Sign out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) {
                return;
              }
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/sign_in',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
