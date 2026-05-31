import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart' as splash;
import 'services/api_service_impl.dart'; // ✅ add this import

void main() async {
  // ✅ make async
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.clearToken(); // ✅ one-time fix: clears corrupted token

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SafeSphereApp());
}

class SafeSphereApp extends StatelessWidget {
  const SafeSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const splash.SplashScreen(),
    );
  }
}
