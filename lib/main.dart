import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'theme/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Request Notification Permissions (for iOS and Android 13+)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final token = await AuthService.getToken();
  final hasSession = token != null && token.isNotEmpty;

  // 3. Handle Token Registration if user is logged in
  if (hasSession) {
    try {
      String? fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        await ApiService.registerFcmToken(fcmToken, 'device_id_placeholder', 'android');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  runApp(InsuredApp(hasSession: hasSession));
}

class InsuredApp extends StatelessWidget {
  final bool hasSession;

  const InsuredApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بوابة المريض',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: DesignSystem.bgDeepDark,
        colorScheme: ColorScheme.light(
          primary: DesignSystem.blue,
          secondary: DesignSystem.emerald,
          surface: DesignSystem.bgPhone,
          error: DesignSystem.rose,
        ),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
        cardTheme: CardThemeData(
          color: DesignSystem.bgPhone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: DesignSystem.buttonTextStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DesignSystem.bgPhone,
          labelStyle: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: DesignSystem.blue, width: 1.5),
          ),
        ),
      ),
      home: hasSession ? const HomeScreen() : const LoginScreen(),
    );
  }
}
