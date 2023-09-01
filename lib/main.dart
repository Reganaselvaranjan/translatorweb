import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videoweb/firebase_options.dart';
import 'package:videoweb/home.dart';
import 'package:videoweb/loginnew.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // return const GetMaterialApp(
    //   debugShowCheckedModeBanner: false,
    //   home: Login(),
    // );
    if (authService.isUserLoggedIn()) {
      return const GetMaterialApp(
        debugShowCheckedModeBanner: false,
        home: Home(),
      );
    } else {
      return const GetMaterialApp(
        debugShowCheckedModeBanner: false,
        home: Login(),
      );
    }
  }
}
