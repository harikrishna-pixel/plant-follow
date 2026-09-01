import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/navigation/v1_nav.dart';
import 'package:plantidentifier/provider/folder_provider.dart';
import 'package:plantidentifier/provider/plant_history_provider.dart';
import 'package:plantidentifier/provider/plant_provider.dart';
import 'package:plantidentifier/provider/recovery_provider.dart';
import 'package:plantidentifier/provider/reminder_provider.dart';
import 'package:plantidentifier/provider/location_provider.dart';
import 'package:plantidentifier/provider/care_rule_provider.dart';
import 'package:plantidentifier/services/phase3_smoke_seed.dart';
import 'package:plantidentifier/services/plant_local.dart';
import 'package:plantidentifier/services/recovery_store.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:plantidentifier/view/screens/camera/camera_entry_sheet.dart';
import 'package:plantidentifier/view/screens/diagnosis/plant_diagnosis_screen.dart';
import 'package:plantidentifier/view/screens/diagnosis/recovery_checkin_screen.dart';
import 'package:plantidentifier/view/screens/scan_screen.dart';
import 'package:provider/provider.dart';

Widget _phase3App() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PlantProvider()),
      ChangeNotifierProvider(create: (_) => FolderProvider()),
      ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ChangeNotifierProvider(create: (_) => RecoveryProvider()),
      ChangeNotifierProvider(create: (_) => PlantHistoryProvider()),
      ChangeNotifierProvider(create: (_) => LocationProvider()),
      ChangeNotifierProvider(create: (_) => CareRuleProvider()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          home: const BottomNavExample(),
        );
      },
    ),
  );
}

Future<void> _shortPump(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Phase 3 simulator smoke', (tester) async {
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp();
    await LocalStorageService.init();
    await Phase3SmokeSeed.maybeSeed();

    await tester.pumpWidget(_phase3App());
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(V1Nav.todayLabel), findsWidgets);
    expect(find.text(V1Nav.plantsLabel), findsOneWidget);
    expect(find.text(V1Nav.meLabel), findsOneWidget);
    expect(find.text('Ask Me'), findsNothing);
    expect(find.text('Protect plants from the heat'), findsNothing);
    expect(find.text('A chilly stretch'), findsNothing);
    expect(find.text('Check on Monstera'), findsOneWidget);
    expect(find.text('Check on Pothos'), findsOneWidget);
    expect(find.textContaining('Day 3'), findsOneWidget);
    expect(find.textContaining('Day 7'), findsOneWidget);

    await tester.tap(find.text('Check now').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RecoveryCheckInScreen), findsOneWidget);
    expect(find.text('Day 3 check-in'), findsOneWidget);
    await tester.tap(find.text('Use sample photo'));
    await _shortPump(tester);
    await tester.tap(find.text('Better'));
    await _shortPump(tester);
    await tester.tap(find.text('Save check-in'));
    await tester.pump(const Duration(seconds: 2));

    expect(
      RecoveryStore.checkInsForCase(Phase3SmokeSeed.day3CaseId),
      isNotEmpty,
    );
    final day3Case = RecoveryStore.getCase(Phase3SmokeSeed.day3CaseId);
    expect(day3Case?.day3CompletedAt, isNotNull);
    expect(day3Case?.status, RecoveryCaseStatus.awaitingDay7);

    await tester.pumpWidget(_phase3App());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Check on Monstera'), findsNothing);
    expect(find.text('Check on Pothos'), findsOneWidget);
    expect(find.textContaining('Day 7'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -240),
    );
    await _shortPump(tester);
    expect(find.textContaining('Fern'), findsWidgets);

    await tester.tap(find.text('Check now'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Day 7 check-in'), findsOneWidget);
    Get.back();
    await _shortPump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CameraEntrySheet), findsOneWidget);
    expect(find.text('Identify'), findsOneWidget);
    expect(find.text('Diagnose'), findsOneWidget);
    await tester.tap(find.text('Identify'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ScanScreen), findsOneWidget);
    Get.back();
    await _shortPump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Diagnose'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PlantDiagnosisScreen), findsOneWidget);
    Get.back();
    await _shortPump(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text(V1Nav.plantsLabel));
    await _shortPump(tester);
    expect(find.text('All plants'), findsOneWidget);
    await tester.tap(find.text('All plants'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Monstera').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Something's wrong"), findsOneWidget);
    Get.back();
    await _shortPump(tester);
    Get.back();
    await _shortPump(tester);

    await tester.tap(find.text(V1Nav.meLabel));
    await _shortPump(tester);
    expect(find.text(MeSecondaryTools.aiBotanist), findsOneWidget);
    await tester.tap(find.text(MeSecondaryTools.aiBotanist));
    await tester.pump(const Duration(seconds: 1));
    Get.back();
    await _shortPump(tester);

    await tester.tap(find.text(V1Nav.meLabel));
    await _shortPump(tester);
    for (final tool in [
      MeSecondaryTools.search,
      MeSecondaryTools.lightMeter,
      MeSecondaryTools.weather,
    ]) {
      await tester.ensureVisible(find.text(tool));
      await tester.tap(find.text(tool));
      await tester.pump(const Duration(seconds: 1));
      Get.back();
      await _shortPump(tester);
    }

    expect(find.text('Ask Me'), findsNothing);
  });
}
