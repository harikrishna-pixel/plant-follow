import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';

void main() {
  test('fromFirestore accepts mixed Firestore field types', () {
    final wallet = UserWallet.fromFirestore('uid-1', {
      'referred': 1,
      'referredBy': 'abc',
      'availableScans': '4',
      'totalScansEarned': 7,
      'totalScansUsed': 2.0,
      'totalReferrals': '1',
      'shareCountToday': 0,
      'shareCoins': '20',
      'coinEarningSharesToday': 1,
      'referralCode': 'PLANT123',
    });

    expect(wallet.referred, isTrue);
    expect(wallet.referredBy, 'abc');
    expect(wallet.availableScans, 4);
    expect(wallet.totalScansEarned, 7);
    expect(wallet.totalScansUsed, 2);
    expect(wallet.totalReferrals, 1);
    expect(wallet.shareCoins, 20);
    expect(wallet.referralCode, 'PLANT123');
  });

  test('fromFirestore keeps empty missing fields at existing defaults', () {
    final wallet = UserWallet.fromFirestore('uid-2', {});
    expect(wallet.referred, isFalse);
    expect(wallet.availableScans, 0);
    expect(wallet.shareCoins, 0);
    expect(wallet.referralCode, isNotEmpty);
  });
}
