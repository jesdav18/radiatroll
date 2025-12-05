import 'package:flutter/material.dart';
import 'package:radiatroll/radio_activo_tester_pager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RadiaTrollApp());
}

class RadiaTrollApp extends StatelessWidget {
  const RadiaTrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadiaTroll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
        ),
      ),
      home: const RadioactivoTesterPage(),
    );
  }
}