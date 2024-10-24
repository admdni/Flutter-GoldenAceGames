import 'package:flutter/material.dart';
import 'package:golden_ace_games/homePage.dart';

void main() {
  runApp(const MyApp());
}

String appName = 'Golden Ace Games';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      home: GoldenAceHome(),
    );
  }
}
