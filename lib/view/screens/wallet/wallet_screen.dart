import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';
import 'package:plantidentifier/services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  UserWallet? _wallet;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet({bool forceServer = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _wallet = null;
        _loading = false;
        _error = 'Please sign in to view your wallet.';
      });
      return;
    }

    try {
      final wallet = forceServer
          ? await WalletService.instance.forceRefreshWallet(user.uid)
          : await WalletService.instance.ensureUserWallet(user);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wallet = null;
        _loading = false;
        _error = 'Unable to load wallet. Pull to refresh or try again later.';
      });
      debugPrint('Failed to load wallet: $e');
    }
  }

  int _coinsFromScans(int scans) => scans * 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Wallet',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _fetchWallet(forceServer: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _fetchWallet);
    }

    final wallet = _wallet;

    if (wallet == null) {
      return _ErrorState(
        message: 'Wallet not available. Pull to refresh.',
        onRetry: _fetchWallet,
      );
    }

    final availableCoins = _coinsFromScans(wallet.availableScans);
    final totalCoinsEarned = _coinsFromScans(wallet.totalScansEarned);
    final coinsUsed = _coinsFromScans(wallet.totalScansUsed);
    final formatter = NumberFormat('#,###');

    return RefreshIndicator(
      onRefresh: () => _fetchWallet(forceServer: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          _BalanceCard(
            coins: formatter.format(availableCoins),
            scans: wallet.availableScans,
            onInfoTap: () => _showConversionInfo(context),
          ),
          const SizedBox(height: 24),
          _StatsGrid(
            totalCoins: formatter.format(totalCoinsEarned),
            usedCoins: formatter.format(coinsUsed),
            totalReferrals: wallet.totalReferrals,
            referred: wallet.referred,
          ),
          const SizedBox(height: 24),
          _ShareProgressCard(
            shareCoins: wallet.shareCoins,
            coinEarningSharesToday: wallet.coinEarningSharesToday,
          ),
          const SizedBox(height: 24),
          _ReferralCard(
            referralCode: wallet.referralCode,
            referred: wallet.referred,
            referredBy: wallet.referredBy,
            onCopy: () => _copyReferralCode(wallet.referralCode),
            onShare: () => _shareReferralCode(wallet.referralCode),
          ),
          const SizedBox(height: 24),
          _ActivityCard(
            shareCountToday: wallet.shareCountToday,
            lastShareDate: wallet.lastShareDate,
            lastAdRewardAt: wallet.lastAdRewardAt,
          ),
          const SizedBox(height: 32),
          _InfoBanner(),
        ],
      ),
    );
  }

  void _copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    Fluttertoast.showToast(
      msg: 'Referral code copied!',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: const Color(0xFF388E3C),
    );
  }

  Future<void> _shareReferralCode(String referralCode) async {
    if (!mounted) return;
    
    const appStoreLink = 'https://apps.apple.com/app/id/6752886333';
    
    final shareMessage = '''
🌿 Join me on PlantFollow! 🌱

I've been using this amazing plant care app and thought you'd love it too!

Use my referral code to get started:
🔑 ${referralCode}

Download PlantFollow - your plant care companion:
$appStoreLink

Let's grow together! 💚
''';
    
    final screenSize = MediaQuery.of(context).size;
    final shareOrigin = Rect.fromCenter(
      center: Offset(
        screenSize.width / 2,
        screenSize.height / 2,
      ),
      width: screenSize.width * 0.5,
      height: screenSize.height * 0.5,
    );
    
    await Share.share(
      shareMessage,
      sharePositionOrigin: shareOrigin,
    );
  }

  void _showConversionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'How your actions add up coins!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConversionRow(label: '1 Scan', value: '100 Coins'),
            const SizedBox(height: 12),
            _ConversionRow(label: '2 Scans', value: '200 Coins'),
            const SizedBox(height: 12),
            _ConversionRow(label: 'Bonus Share', value: '+20 Coins'),
            const SizedBox(height: 12),
            _ConversionRow(label: 'Ad Reward', value: '+100 Coins'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.coins,
    required this.scans,
    required this.onInfoTap,
  });

  final String coins;
  final int scans;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onInfoTap,
                tooltip: 'Coin conversion',
                icon: const Icon(Icons.info_outline, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  // color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Colors.black.withOpacity(0.1),
                  //     blurRadius: 8,
                  //     offset: const Offset(0, 2),
                  //   ),
                  // ],
                ),
                child: Image.asset(
                  "assets/coin.png",
                  width: 45,
                  height: 45,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Coins',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coins,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$scans scans available',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalCoins,
    required this.usedCoins,
    required this.totalReferrals,
    required this.referred,
  });

  final String totalCoins;
  final String usedCoins;
  final int totalReferrals;
  final bool referred;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.savings_rounded,
                  title: 'Coins Earned',
                  value: totalCoins,
                  color: const Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_down_rounded,
                  title: 'Coins Used',
                  value: usedCoins,
                  color: const Color(0xFFEF6C00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Referrals',
                  value: '$totalReferrals',
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: referred ? Icons.verified_rounded : Icons.link_off,
                  title: 'Referral Status',
                  value: referred ? 'Activated' : 'Not Claimed',
                  color: referred ? const Color(0xFF8E24AA) : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.black54,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.referralCode,
    required this.referred,
    required this.referredBy,
    required this.onCopy,
    required this.onShare,
  });

  final String referralCode;
  final bool referred;
  final String? referredBy;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Referral Rewards',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBEF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralCode,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                    'Copy',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              label: Text(
                'Share Referral Code',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                referred ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: referred ? const Color(0xFF4CAF50) : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  referred
                      ? 'Referral activated${referredBy != null ? " by $referredBy" : ""}.'
                      : 'Use a friend’s referral code to unlock bonus coins.',
                  style: GoogleFonts.inter(
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.shareCountToday,
    required this.lastShareDate,
    required this.lastAdRewardAt,
  });

  final int shareCountToday;
  final DateTime? lastShareDate;
  final DateTime? lastAdRewardAt;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timelapse_rounded, color: Colors.blueGrey.shade600),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ActivityRow(
            icon: Icons.share_rounded,
            color: const Color(0xFF42A5F5),
            title: 'Shares Today',
            value: '$shareCountToday shares today',
          ),
          const SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.campaign_rounded,
            color: const Color(0xFFFFA726),
            title: 'Last Share Reward',
            value: lastShareDate != null
                ? dateFormat.format(lastShareDate!.toLocal())
                : 'Not claimed yet',
          ),
          const SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.movie_filter_rounded,
            color: const Color(0xFF8D6E63),
            title: 'Last Ad Reward',
            value: lastAdRewardAt != null
                ? dateFormat.format(lastAdRewardAt!.toLocal())
                : 'No ad reward yet',
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareProgressCard extends StatelessWidget {
  const _ShareProgressCard({
    required this.shareCoins,
    required this.coinEarningSharesToday,
  });

  final int shareCoins;
  final int coinEarningSharesToday;

  @override
  Widget build(BuildContext context) {
    final coinsNeeded = 100 - shareCoins;
    final sharesNeeded = (coinsNeeded / 20).ceil();
    final progress = shareCoins / 100.0;
    final remainingSharesForCoins = UserWallet.maxCoinEarningSharesPerDay - coinEarningSharesToday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF66BB6A).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$shareCoins/100 coins',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remainingSharesForCoins <= 0
                ? 'You\'ve reached today\'s limit (3 shares). Share again tomorrow to earn more coins!'
                : sharesNeeded > 0
                    ? 'Share $sharesNeeded more time${sharesNeeded > 1 ? 's' : ''} to reach 100 coins for 1 scan! ($remainingSharesForCoins share${remainingSharesForCoins > 1 ? 's' : ''} left today to earn coins)'
                    : '🎉 You\'ve reached 100 coins! 1 scan will be added.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: remainingSharesForCoins <= 0 ? Colors.orange.shade700 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Color(0xFF388E3C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Invite friends with your referral code to earn extra coins. '
              'Watch rewarded ads or share the app once daily to keep earning!',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function({bool forceServer}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => onRetry(forceServer: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversionRow extends StatelessWidget {
  const _ConversionRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF388E3C),
          ),
        ),
      ],
    );
  }
}

