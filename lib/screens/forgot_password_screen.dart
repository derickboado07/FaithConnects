// ═══════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN — Password recovery screen.
// Nagbibigay ng option para i-reset ang password via Firebase email reset.
// Steps:
//   1. I-enter ang email address
//   2. Mag-se-send ng password reset email via Firebase Auth
//   3. Pwede ring mag-enter ng new password manually (optional form)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Screen para sa password reset — nagpapadala ng Firebase reset email sa user.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String? _enteredEmail;                              // Email na nakapasok na bago mag-proceed
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _obscureNew = true;       // Visibility toggle para sa new password field
  bool _obscureConfirm = true;   // Visibility toggle para sa confirm password field

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
  /// Nagva-validate ng email format, tapos nagpapadala ng Firebase password reset link.
  void _findAccount() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email.')),
      );
      return;
    }
    // Basic email format check
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    // Attempt to send Firebase password reset email
    fb_auth.FirebaseAuth.instance
        .sendPasswordResetEmail(email: email)
        .then((_) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reset Email Sent'),
          content: const Text(
              'A password reset email has been sent. Check your inbox.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }).catchError((e) {
      String msg = 'Failed to send reset email.';
      if (e is fb_auth.FirebaseAuthException) {
        if (e.code == 'user-not-found') msg = 'No account found for that email.';
        if (e.code == 'invalid-email') msg = 'The email address is invalid.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  void _enterPressed() {
    if (_enteredEmail == null) return;
    setState(() {});
  }

  void _savePassword() {
    final a = _newPwdCtrl.text.trim();
    final b = _confirmCtrl.text.trim();

    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    // Simulate success (in this project passwords are handled locally for demo)
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Your password has been successfully updated.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              if (_enteredEmail == null) ...[
                const Text(
                  'Enter your account email and continue.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF444444)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _findAccount,
                    child: const Text('Find My Account'),
                  ),
                ),
              ] else ...[
                const SizedBox.shrink(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
