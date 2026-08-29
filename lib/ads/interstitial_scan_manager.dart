import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialScanManager {
  InterstitialScanManager._internal();

  static final InterstitialScanManager instance =
  InterstitialScanManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Use only iOS Ad Unit ID
  static const String _iosUnitId = 'ca-app-pub-4194577750257069/3319407879';

  void warmUp() {
    if (_interstitialAd != null || _isLoading) return;
    _loadInterstitial();
  }

  Future<bool> showExtraScanAd() async {
    if (_interstitialAd == null && !_isLoading) {
      await _loadInterstitial();
    }

    final ad = _interstitialAd;
    if (ad == null) return false;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _interstitialAd = null;
      },
      onAdDismissedFullScreenContent: (_) {
        completer.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        if (!completer.isCompleted) completer.complete(false);
        _loadInterstitial();
        if (kDebugMode) {
          debugPrint('Interstitial failed to show: $error');
        }
      },
    );

    ad.show();
    return completer.future;
  }

  Future<void> _loadInterstitial() async {
    if (_isLoading) return;
    _isLoading = true;

    await InterstitialAd.load(
      adUnitId: _iosUnitId,   // iOS only
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('Failed to load interstitial: $error');
          }
        },
      ),
    );
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
