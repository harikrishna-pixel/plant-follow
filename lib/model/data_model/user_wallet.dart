import 'package:cloud_firestore/cloud_firestore.dart';

class UserWallet {
  const UserWallet({
    required this.uid,
    required this.availableScans,
    required this.referralCode,
    this.referred = false,
    this.referredBy,
    this.totalScansEarned = 0,
    this.totalScansUsed = 0,
    this.totalReferrals = 0,
    this.shareCountToday = 0,
    this.shareCoins = 0,
    this.coinEarningSharesToday = 0,
    this.lastShareDate,
    this.lastAdRewardAt,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final bool referred;
  final String? referredBy;
  final int availableScans;
  final int totalScansEarned;
  final int totalScansUsed;
  final int totalReferrals;
  final int shareCountToday;
  final int shareCoins;
  final int coinEarningSharesToday;
  final DateTime? lastShareDate;
  final DateTime? lastAdRewardAt;
  final String referralCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const int maxCoinEarningSharesPerDay = 3;

  bool get hasShareRewardAvailable {
    // Check if user can still earn coins from shares today
    if (lastShareDate == null) return true;
    final nowUtc = DateTime.now().toUtc();
    final beginToday = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final lastShareUtc = lastShareDate!.toUtc();
    final beginLastShareDay =
        DateTime.utc(lastShareUtc.year, lastShareUtc.month, lastShareUtc.day);
    if (beginLastShareDay != beginToday) {
      return true;
    }
    return coinEarningSharesToday < maxCoinEarningSharesPerDay;
  }

  UserWallet copyWith({
    bool? referred,
    String? referredBy,
    int? availableScans,
    int? totalScansEarned,
    int? totalScansUsed,
    int? totalReferrals,
    int? shareCountToday,
    int? shareCoins,
    int? coinEarningSharesToday,
    DateTime? lastShareDate,
    DateTime? lastAdRewardAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserWallet(
      uid: uid,
      referralCode: referralCode,
      referred: referred ?? this.referred,
      referredBy: referredBy ?? this.referredBy,
      availableScans: availableScans ?? this.availableScans,
      totalScansEarned: totalScansEarned ?? this.totalScansEarned,
      totalScansUsed: totalScansUsed ?? this.totalScansUsed,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      shareCountToday: shareCountToday ?? this.shareCountToday,
      shareCoins: shareCoins ?? this.shareCoins,
      coinEarningSharesToday: coinEarningSharesToday ?? this.coinEarningSharesToday,
      lastShareDate: lastShareDate ?? this.lastShareDate,
      lastAdRewardAt: lastAdRewardAt ?? this.lastAdRewardAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'referred': referred,
        'referredBy': referredBy,
        'availableScans': availableScans,
        'totalScansEarned': totalScansEarned,
        'totalScansUsed': totalScansUsed,
        'totalReferrals': totalReferrals,
        'shareCountToday': shareCountToday,
        'shareCoins': shareCoins,
        'coinEarningSharesToday': coinEarningSharesToday,
        'lastShareDate':
            lastShareDate != null ? Timestamp.fromDate(lastShareDate!) : null,
        'lastAdRewardAt': lastAdRewardAt != null
            ? Timestamp.fromDate(lastAdRewardAt!)
            : null,
        'referralCode': referralCode,
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      };

  factory UserWallet.initial(String uid) {
    final now = DateTime.now().toUtc();
    return UserWallet(
      uid: uid,
      referred: false,
      referredBy: null,
      availableScans: 3,
      totalScansEarned: 3,
      totalScansUsed: 0,
      totalReferrals: 0,
      shareCountToday: 0,
      shareCoins: 0,
      coinEarningSharesToday: 0,
      lastShareDate: null,
      lastAdRewardAt: null,
      referralCode: _generateReferralCode(uid),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserWallet.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    return UserWallet(
      uid: uid,
      referred: _asBool(data['referred']),
      referredBy: _asNullableString(data['referredBy']),
      availableScans: _asInt(data['availableScans']),
      totalScansEarned: _asInt(data['totalScansEarned']),
      totalScansUsed: _asInt(data['totalScansUsed']),
      totalReferrals: _asInt(data['totalReferrals']),
      shareCountToday: _asInt(data['shareCountToday']),
      shareCoins: _asInt(data['shareCoins']),
      coinEarningSharesToday: _asInt(data['coinEarningSharesToday']),
      lastShareDate: _parseDate(data['lastShareDate']),
      lastAdRewardAt: _parseDate(data['lastAdRewardAt']),
      referralCode: _asNullableString(data['referralCode']) ??
          _generateReferralCode(uid),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static String _generateReferralCode(String uid) {
    final sanitized = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (sanitized.length >= 8) {
      return sanitized.substring(0, 8);
    }
    if (sanitized.isEmpty) {
      return 'PLANT${uid.hashCode.abs().toRadixString(36).toUpperCase()}';
    }
    final filler =
        uid.hashCode.abs().toRadixString(36).padLeft(6, '0').toUpperCase();
    return (sanitized + filler).substring(0, 8);
  }
}

