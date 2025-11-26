import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBa02FAgtc-91aVenSmO9Cr4qLrIG2kkfQ",
      appId: "1:252278755172:android:e9633f21b0f916e679f471",
      messagingSenderId: "252278755172",
      projectId: "smart-room-70ea4",
      databaseURL:
      "https://smart-room-70ea4-default-rtdb.asia-southeast1.firebasedatabase.app",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Room',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }


        if (snapshot.hasData) {
          return const SmartRoomDashboard();
        }


        return const LoginPage();
      },
    );
  }
}
