/// Phase 6.5: normal identification is unlimited. Legacy wallet/quota
/// infrastructure stays in [WalletService] / Firestore for backward
/// compatibility but must not appear on the Identify path.
class IdentificationPolicy {
  /// Customer-facing Identify UI must never show remaining/free scans.
  static const bool showFreeScanCounter = false;

  /// Identify must not be gated on the legacy local/cloud scan allowance.
  static const bool blockIdentifyOnLegacyQuota = false;

  static bool canStartIdentification({
    bool isSubscribed = false,
    int freeScansRemaining = 0,
  }) {
    if (blockIdentifyOnLegacyQuota) {
      return isSubscribed || freeScansRemaining > 0;
    }
    return true;
  }

  static String? visibleRemainingLabel(int remaining) {
    if (!showFreeScanCounter) return null;
    return 'Enjoy Your $remaining Free Scans';
  }
}
