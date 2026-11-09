import 'package:flutter/material.dart';

import 'screens/register_screen.dart';

void main() {
  runApp(const WiseWalletApp());
}

class WiseWalletApp extends StatelessWidget {
  const WiseWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wise Wallet',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD5D2F0)),
        useMaterial3: true,
      ),
      home: const RegisterScreen(),
    );
  }
}
