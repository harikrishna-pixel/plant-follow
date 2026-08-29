import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantidentifier/services/wallet_service.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';
import '../../../model/data_model/plant_history_model.dart';
import '../../../provider/plant_history_provider.dart';
import '../../../provider/plant_provider.dart';
import '../../../model/data_model/plant_model.dart';

class PlantHistoryDetailScreen extends StatelessWidget {
  final PlantHistory plantHistory;

  const PlantHistoryDetailScreen({
    super.key,
    required this.plantHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plant Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plant Image and Name Section
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Plant Image - Small Corner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (plantHistory.imagePath.isNotEmpty &&
                            File(plantHistory.imagePath).existsSync())
                        ? Image.file(
                            File(plantHistory.imagePath),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_florist,
                              size: 40,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  // Plant Name & Scientific Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plantHistory.plantName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (plantHistory.scientificName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            plantHistory.scientificName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Scan Date
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(plantHistory.scannedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Description Section
            if (plantHistory.description.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      plantHistory.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Delete from History
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        _showDeleteDialog(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF4CAF50), size: 20),
                      onPressed: () async => _sharePlant(),
                      tooltip: 'Share',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete from History?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove "${plantHistory.plantName}" from your history?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              final provider = Provider.of<PlantHistoryProvider>(context, listen: false);
              provider.deleteHistoryItem(plantHistory.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to history screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Removed from history', style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                  backgroundColor: const Color(0xFFF44336),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveToFavorites(BuildContext context) {
    // Convert PlantHistory to Plant model
    final plant = Plant(
      name: plantHistory.plantName,
      scientificName: plantHistory.scientificName,
      description: plantHistory.description,
      taxonomy: {},
      nativeRegion: '',
      growthSeason: '',
      toxicity: '',
      careGuide: {},
      healthScan: '',
      commonPests: '',
      commonDiseases: '',
      usage: '',
      funFact: '',
      imagePath: plantHistory.imagePath.isNotEmpty ? plantHistory.imagePath : null,
    );

    final provider = Provider.of<PlantProvider>(context, listen: false);
    final success = provider.saveFavorite(plant);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Saved to favorites!', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('Already in favorites', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _sharePlant() async {
    const appStoreLink = 'https://apps.apple.com/app/id/6752886333';
    
    final text = '''
🌿 ${plantHistory.plantName}
${plantHistory.scientificName.isNotEmpty ? '🔬 ${plantHistory.scientificName}\n' : ''}
📅 Scanned on: ${DateFormat('MMM dd, yyyy').format(plantHistory.scannedAt)}

${plantHistory.description}

Shared from PlantFollow
📱 Download the app: $appStoreLink
''';
    await Share.share(text);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final granted =
            await WalletService.instance.tryGrantShareReward(user.uid);
        if (granted) {
          final wallet =
              await WalletService.instance.forceRefreshWallet(user.uid);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'free_scans_remaining',
            wallet.availableScans,
          );
          final shareCoins = wallet.shareCoins;
          final coinEarningSharesToday = wallet.coinEarningSharesToday;
          final remainingSharesForCoins = UserWallet.maxCoinEarningSharesPerDay - coinEarningSharesToday;
          
          String message;
          if (remainingSharesForCoins <= 0) {
            message = "✅ Share recorded! You've reached today's limit (3 shares). Share again tomorrow to earn more coins!";
          } else {
            final coinsNeeded = 100 - shareCoins;
            final sharesNeeded = (coinsNeeded / 20).ceil();
            
            if (shareCoins >= 100) {
              message = "🎉 +1 scan unlocked! You earned 100 coins from sharing!";
            } else {
              message = "🎁 +20 coins earned! ($shareCoins/100 coins) $remainingSharesForCoins share${remainingSharesForCoins > 1 ? 's' : ''} left today to earn coins!";
            }
          }
          
          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: remainingSharesForCoins <= 0 ? Colors.orange : const Color(0xFF388E3C),
          );
        } else {
          // This should not happen now since there's no daily limit
          // But keeping for safety
          Fluttertoast.showToast(
            msg: "Unable to process share reward. Please try again.",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.orange,
          );
        }
      } catch (e) {
        debugPrint('Failed to apply share reward: $e');
      }
    }
  }
}

