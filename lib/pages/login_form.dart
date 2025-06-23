import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_tahong_market/utils/error_utils.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _loginKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Define admin credentials
  final String _adminEmail = 'admin@123.com';
  final String _adminPassword = 'admin321';

  bool _isAdminCredentials(String email, String password) {
    return email.toLowerCase().trim() == _adminEmail && 
           password.trim() == _adminPassword;
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Check if admin credentials
      if (_isAdminCredentials(email, password)) {
        try {
          // Try to sign in admin with Firebase
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          // If admin account doesn't exist, create it
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        
        Navigator.pushReplacementNamed(context, '/admin');
        return;
      }

      // Regular user login
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navigate to main app for regular users
      Navigator.pushReplacementNamed(context, '/main');
      
    } on FirebaseAuthException catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Failed'),
          content: Text(getFriendlyError(e.code)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Handle admin login errors or other errors
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Failed'),
          content: const Text('Invalid credentials. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _loginKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              validator: (value) =>
                  value!.contains('@') ? null : "Enter a valid email",
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
              validator: (value) =>
                  value!.length >= 6 ? null : "Minimum 6 characters",
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _login,
                    child: const Text("Login", style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}