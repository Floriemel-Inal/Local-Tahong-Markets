import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';  // Add this import

import 'pages/landing_page.dart';
import 'pages/main_page.dart';
import 'pages/cart_page.dart';
import 'pages/profile_page.dart';
import 'pages/auth_page.dart';
import 'pages/history.dart'; // This contains both login and signup using tabs

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensures Flutter binding before Firebase init
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDyQbi2SA4H3LXG1N8MXKLUBVCqqZ4qXBU",
      authDomain: "local-tahong-market.firebaseapp.com",
      projectId: "local-tahong-market",
      storageBucket: "local-tahong-market.firebasestorage.app",
      messagingSenderId: "282785094771",
      appId: "1:282785094771:web:b9e8ae7f1d422badc35e06",
      measurementId: "G-DEVDLVVVG8",
    ),
  );
  runApp(LocalTahongMarketApp());
}

class LocalTahongMarketApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Tahong Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(),
        '/main': (context) => MainPage(),
        '/cart': (context) => CartPage(),
        '/profile': (context) => ProfilePage(),
        '/history': (context) => HistoryPage(),
        '/auth': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
          return AuthScreen(initialTab: args);
        },
      },
    );
  }
}
