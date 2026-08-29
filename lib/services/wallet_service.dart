import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';

class WalletService {
  WalletService._();

  static final WalletService instance = WalletService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _userCollection =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _userCollection.doc(uid);

  /// Ensures the wallet document exists for the authenticated user
  /// and returns the latest snapshot as [UserWallet].
  Future<UserWallet> ensureUserWallet(User user) async {
    final docRef = _userDoc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      final wallet = UserWallet.initial(user.uid);
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        ...wallet.toMap(),
      });
      return wallet;
    }

    final data = snapshot.data() ?? {};
    final wallet = UserWallet.fromFirestore(user.uid, data);

    if (data['referralCode'] == null) {
      await docRef.update({
        'referralCode': wallet.referralCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return wallet;
  }

  Future<UserWallet?> fetchWallet(String uid) async {
    final docRef = _userDoc(uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      return null;
    }
    return UserWallet.fromFirestore(uid, snapshot.data() ?? {});
  }

  Future<UserWallet> forceRefreshWallet(String uid) async {
    final docRef = _userDoc(uid);
    final snapshot = await docRef.get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      final wallet = UserWallet.initial(uid);
      await docRef.set({
        'uid': uid,
        ...wallet.toMap(),
      });
      return wallet;
    }
    return UserWallet.fromFirestore(uid, snapshot.data() ?? {});
  }

  Future<void> setAvailableScans(String uid, int availableScans) async {
    final docRef = _userDoc(uid);
    await docRef.set({
      'uid': uid,
      'availableScans': availableScans,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> consumeScan(String uid) async {
    bool success = false;
    await _firestore.runTransaction((txn) async {
      final docRef = _userDoc(uid);
      final snapshot = await txn.get(docRef);

      if (!snapshot.exists) {
        final wallet = UserWallet.initial(uid);
        txn.set(docRef, {
          'uid': uid,
          ...wallet.toMap(),
        });
        success = false;
        return;
      }

      final data = snapshot.data() ?? {};
      final currentScans = (data['availableScans'] as num?)?.toInt() ?? 0;
      if (currentScans <= 0) {
        success = false;
        return;
      }

      txn.update(docRef, {
        'availableScans': currentScans - 1,
        'totalScansUsed': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      success = true;
    });
    return success;
  }

  Future<void> addScans({
    required String uid,
    required int count,
    String? source,
  }) async {
    await _userDoc(uid).set({
      'uid': uid,
      'availableScans': FieldValue.increment(count),
      'totalScansEarned': FieldValue.increment(count),
      if (source != null) 'sources.$source': FieldValue.increment(count),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> tryGrantShareReward(String uid) async {
    bool granted = false;
    await _firestore.runTransaction((txn) async {
      final docRef = _userDoc(uid);
      final snapshot = await txn.get(docRef);

      if (!snapshot.exists) {
        final wallet = UserWallet.initial(uid);
        txn.set(docRef, {
          'uid': uid,
          ...wallet.toMap(),
        });
        return;
      }

      final data = snapshot.data() ?? {};
      final wallet = UserWallet.fromFirestore(uid, data);
      final nowUtc = DateTime.now().toUtc();
      final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final lastShare = wallet.lastShareDate?.toUtc();
      int shareCountToday = wallet.shareCountToday;
      int coinEarningSharesToday = wallet.coinEarningSharesToday;

      // Reset counters if it's a new day
      if (lastShare == null ||
          DateTime.utc(lastShare.year, lastShare.month, lastShare.day) !=
              todayStart) {
        shareCountToday = 0;
        coinEarningSharesToday = 0;
      }

      // Always increment total share count (unlimited shares allowed)
      shareCountToday += 1;

      final updateData = <String, dynamic>{
        'shareCountToday': shareCountToday,
        'lastShareDate': Timestamp.fromDate(nowUtc),
        'sources.share': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only grant coins if user hasn't reached the daily limit of 3 coin-earning shares
      if (coinEarningSharesToday < UserWallet.maxCoinEarningSharesPerDay) {
        coinEarningSharesToday += 1;
        updateData['coinEarningSharesToday'] = coinEarningSharesToday;

        // Share reward: 20 coins per share (only for first 3 shares per day)
        // After 5 shares (100 coins), convert to 1 scan
        final currentShareCoins = (data['shareCoins'] as num?)?.toInt() ?? 0;
        final newShareCoins = currentShareCoins + 20;
        final scansToAdd = newShareCoins ~/ 100; // Integer division
        final remainingCoins = newShareCoins % 100;

        updateData['shareCoins'] = remainingCoins;

        // If we have enough coins for at least 1 scan, add it
        if (scansToAdd > 0) {
          updateData['availableScans'] = FieldValue.increment(scansToAdd);
          updateData['totalScansEarned'] = FieldValue.increment(scansToAdd);
        }

        granted = true;
      } else {
        // User has reached daily limit - share is recorded but no coins granted
        // Still return true to indicate share was successful, but no coins earned
        granted = true;
      }

      txn.update(docRef, updateData);
    });

    return granted;
  }

  /// Grant welcome share bonus: 3 scans (300 coins) for first-time welcome dialog share
  /// This should only be called once per user (from welcome dialog)
  Future<bool> tryGrantWelcomeShareReward(String uid) async {
    bool granted = false;
    await _firestore.runTransaction((txn) async {
      final docRef = _userDoc(uid);
      final snapshot = await txn.get(docRef);

      if (!snapshot.exists) {
        final wallet = UserWallet.initial(uid);
        txn.set(docRef, {
          'uid': uid,
          ...wallet.toMap(),
        });
        return;
      }

      final data = snapshot.data() ?? {};
      final wallet = UserWallet.fromFirestore(uid, data);
      
      // Check if welcome bonus has already been claimed
      final welcomeBonusClaimed = data['welcomeBonusClaimed'] as bool? ?? false;
      if (welcomeBonusClaimed) {
        // Already claimed, don't grant again
        granted = false;
        return;
      }

      // Grant 3 scans (300 coins = 3 scans)
      // 1 scan = 100 coins, so 3 scans = 300 coins
      final updateData = <String, dynamic>{
        'welcomeBonusClaimed': true,
        'availableScans': FieldValue.increment(3),
        'totalScansEarned': FieldValue.increment(3),
        'sources.welcomeShare': FieldValue.increment(3),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      txn.update(docRef, updateData);
      granted = true;
    });

    return granted;
  }

  Future<void> grantAdReward(String uid) async {
    await _userDoc(uid).set({
      'uid': uid,
      'availableScans': FieldValue.increment(1),
      'totalScansEarned': FieldValue.increment(1),
      'lastAdRewardAt': FieldValue.serverTimestamp(),
      'sources.ad': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> applyReferralCode({
    required String referredUid,
    required String referralCode,
  }) async {
    final normalized = referralCode.trim().toUpperCase();
    final referrerQuery = await _userCollection
        .where('referralCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      return false;
    }

    final referrerDoc = referrerQuery.docs.first.reference;
    final referredDoc = _userDoc(referredUid);

    bool applied = false;

    await _firestore.runTransaction((txn) async {
      final referredSnapshot = await txn.get(referredDoc);

      if (!referredSnapshot.exists) {
        return;
      }

      final referredData = referredSnapshot.data() ?? {};
      final alreadyReferred = referredData['referred'] as bool? ?? false;
      if (alreadyReferred || referrerDoc.id == referredUid) {
        return;
      }

      txn.update(referredDoc, {
        'referred': true,
        'referredBy': referrerDoc.id,
        'availableScans': FieldValue.increment(2),
        'totalScansEarned': FieldValue.increment(2),
        'sources.referral': FieldValue.increment(2),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.update(referrerDoc, {
        'totalReferrals': FieldValue.increment(1),
        'availableScans': FieldValue.increment(2),
        'totalScansEarned': FieldValue.increment(2),
        'sources.referral': FieldValue.increment(2),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      applied = true;
    });

    return applied;
  }

  Future<void> deleteUserWallet(String uid) async {
    final docRef = _userDoc(uid);
    await docRef.delete();
  }
}

