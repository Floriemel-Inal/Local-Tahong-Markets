import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/gradient_background.dart'; // Import the gradient background

class ProfilePage extends StatelessWidget {
  ProfilePage({Key? key}) : super(key: key);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/main');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold background transparent
        appBar: AppBar(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          title: const Text('My Profile'),
          centerTitle: true,
          elevation: 2,
        ),
        body: buildGradientBackground( // Apply the gradient background
          child: Center(
            child: user == null
                ? const Text(
                    'No user logged in.',
                    style: TextStyle(fontSize: 18, color: Colors.white), // Changed to white for better visibility
                  )
                : Card(
                    elevation: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.green.shade200,
                            child: Text(
                              user.displayName != null && user.displayName!.isNotEmpty
                                  ? user.displayName![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 40, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.displayName ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.email, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.email ?? 'No Email',
                                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _auth.signOut();
                                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}