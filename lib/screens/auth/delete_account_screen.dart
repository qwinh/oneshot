import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/theme/app_theme.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _understandsConsequences = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_understandsConsequences) {
      setState(() {
        _errorMessage = 'Please confirm you understand this is permanent.';
      });
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text(
          'Delete account?',
          style: TextStyle(color: kTextPrimary),
        ),
        content: Text(
          'This will permanently delete your account and profile data. '
          'This action cannot be undone.',
          style: kSubtitleText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: kDestructive)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AppAuthProvider>().deleteAccount(
        password: _passwordController.text.trim(),
      );
      // Successful deletion signs the user out; AuthGateRouter will
      // redirect to LoginScreen automatically via the auth stream.
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorMessage = 'Incorrect password. Please try again.';
        } else if (e.code == 'requires-recent-login') {
          _errorMessage =
              'For security, please log out and log back in before deleting your account.';
        } else {
          _errorMessage = e.message ?? 'Failed to delete account.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst(RegExp(r'\[.*?\]\s*'), '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('Delete Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: kDestructive,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Your Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently remove your account, profile, and '
                  'associated data. This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: kSubtitleText,
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kDestructive.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kDestructive.withOpacity(0.5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: kDestructive, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: kSubtitleText,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kDestructive),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Password is required to confirm deletion';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _understandsConsequences,
                        onChanged: (val) {
                          setState(
                            () => _understandsConsequences = val ?? false,
                          );
                        },
                        fillColor: WidgetStateProperty.resolveWith(
                          (states) => kDestructive,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'I understand this action is permanent and cannot be undone.',
                          style: TextStyle(color: kTextPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmAndDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDestructive,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Permanently Delete Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
