import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';


class LogoutService {

  static Future<void> showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const LogoutDialog(),
    );

    if (confirm == true) {
      await performLogout(context);
    }
  }


  static Future<void> performLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.cyanAccent,
          ),
        );
      }
    }
  }


  static Future<void> quickLogout(BuildContext context) async {
    await performLogout(context);
  }
}


class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text('Logout'),
        ],
      ),
      content: const Text('Are you sure you want to logout?'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}


class LogoutButton extends StatelessWidget {
  final bool showConfirmation;
  final IconData icon;
  final String? tooltip;

  const LogoutButton({
    super.key,
    this.showConfirmation = true,
    this.icon = Icons.logout,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip ?? 'Logout',
      onPressed: () {
        if (showConfirmation) {
          LogoutService.showLogoutDialog(context);
        } else {
          LogoutService.quickLogout(context);
        }
      },
    );
  }
}


