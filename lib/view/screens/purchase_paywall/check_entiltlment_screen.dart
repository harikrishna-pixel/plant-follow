// import 'package:ai_plant_based_identifier/view/screens/purchase_paywall/paywall.dart';
// import 'package:flutter/material.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
//
// import '../home_screen.dart';
//
// class CheckEntitlementScreen extends StatefulWidget {
//   const CheckEntitlementScreen({super.key});
//
//   @override
//   State<CheckEntitlementScreen> createState() => _CheckEntitlementScreenState();
// }
//
// class _CheckEntitlementScreenState extends State<CheckEntitlementScreen> {
//   bool? _isPro; // null = still loading
//
//   @override
//   void initState() {
//     super.initState();
//     _checkEntitlement();
//   }
//
//   Future<void> _checkEntitlement() async {
//     try {
//       CustomerInfo customerInfo = await Purchases.getCustomerInfo();
//       bool isPro = customerInfo.entitlements.all["premium"]?.isActive ?? false;
//       setState(() {
//         _isPro = isPro;
//       });
//     } catch (e) {
//       // handle errors (like network issues)
//       setState(() {
//         _isPro = false; // fallback to free
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isPro == null) {
//       // Still checking
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     if (_isPro == true) {
//       return const HomeScreen(); // Premium user
//     } else {
//       return const PaywallScreen(); // Show paywall
//     }
//   }
// }
