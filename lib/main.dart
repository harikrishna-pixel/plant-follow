import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:plantidentifier/provider/folder_provider.dart'
    show FolderProvider;
import 'package:plantidentifier/provider/plant_provider.dart';
import 'package:plantidentifier/provider/reminder_provider.dart';
import 'package:plantidentifier/provider/plant_history_provider.dart';
import 'package:plantidentifier/services/plant_local.dart';
import 'package:plantidentifier/services/notification_service.dart';
import 'package:plantidentifier/view/screens/home_screen.dart';
import 'package:plantidentifier/view/screens/splash_screen.dart';
import 'package:plantidentifier/mixpanel/mixpanel.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  await LocalStorageService.init();
  // Initialize notification service (without requesting permissions)
  await NotificationService.initialize();
  // Initialize Mixpanel
  await MixpanelService.initialize();
  // Note: Permission requests moved to splash screen - they will show after logo appears
  const apiKey = "appl_SnJkowviKrfcXkbqLyMnUhCZLAS";
  await Purchases.configure(PurchasesConfiguration(apiKey));
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => FolderProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => PlantHistoryProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812), // iPhone 11 Pro design size
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return GetMaterialApp(
            title: 'PlantFollow',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF388E3C),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
