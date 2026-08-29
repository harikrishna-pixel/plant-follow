import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseHelper {
  static Future<void> restorePurchases(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    bool loaderVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );
    try {
      final customerInfo = await Purchases.restorePurchases();
      final hasActive = customerInfo.entitlements.active.isNotEmpty;

      if (hasActive) {
        if (loaderVisible && navigator.canPop()) {
          navigator.pop();
          loaderVisible = false;
        }
        // Success dialog with grey background
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey[300],
            title: const Text(
              'Success',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'Your purchases have been restored successfully!',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        );
      } else {
        if (loaderVisible && navigator.canPop()) {
          navigator.pop();
          loaderVisible = false;
        }
        // No subscription dialog with grey background
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey[300],
            title: const Text(
              'Alert',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'No Active Plans Are Available!',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        );
      }
    } on PlatformException catch (e) {
      if (loaderVisible && navigator.canPop()) {
        navigator.pop();
        loaderVisible = false;
      }
      // Restore failed dialog with grey background
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[300],
          title: const Text(
            'Restore Failed',
            style: TextStyle(color: Colors.black),
          ),
          content: Text(
            '${e.message ?? 'Please try again later.'}',
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );
    } finally {
      if (loaderVisible && navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}