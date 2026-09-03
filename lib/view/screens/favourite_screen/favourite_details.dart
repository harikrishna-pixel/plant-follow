import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantidentifier/services/wallet_service.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';

import '../../../model/data_model/plant_model.dart';
import '../../../model/data_model/recovery_models.dart';
import '../../../provider/plant_provider.dart';
import '../../../provider/recovery_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/care_rule_provider.dart';
import '../../../model/data_model/plant_context.dart';
import '../../../services/recovery_logic.dart';
import '../../../services/plant_health_presenter.dart';
import '../../../services/identify_logic.dart';
import '../../../services/identification_result.dart';
import '../../../navigation/plant_workspace_tabs.dart';
import '../diagnosis/plant_diagnosis_screen.dart';
import '../diagnosis/recovery_checkin_screen.dart';
import '../plant_context/plant_context_sheet.dart';
import 'add_to_folder_dialog.dart';
import 'plant_care_tab.dart';
import 'plant_health_tab.dart';
import 'plant_timeline_tab.dart';
import 'plant_grow_card.dart';
import '../result_screens/identify_trust_card.dart';

class FavoriteDetailScreen extends StatefulWidget {
  final Plant plant;
  const FavoriteDetailScreen({super.key, required this.plant});

  @override
  State<FavoriteDetailScreen> createState() => _FavoriteDetailScreenState();
}

class _FavoriteDetailScreenState extends State<FavoriteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PlantWorkspaceTabs.labels.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sharePlant() async {
    const appStoreLink = 'https://apps.apple.com/app/id/6752886333';

    final shareMessage =
        '''
🌿 Hey, plant lover! 💚

I just found the cutest little helper for my plants and thought to share it with you! It's called PlantFollow & Care, and honestly… it feels like having a plant expert in your pocket.

Whether you're a proud plant parent or just trying to explore gardening, this app helps you:
🌱 Instantly identify any plant!
🌱 Know exactly how to care for it!
🌱 Get gentle reminders so you never forget again
🌱 Even helps you save sick plants before it's too late!

I didn't realise how connected I could feel to my plants until I actually started understanding what they need. If you're even a little obsessed with the plants around, you've gotta check it out.

Download PlantFollow  & Care - your green thumb will thank you! 💚

$appStoreLink
''';

    final renderBox =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final shareOrigin = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : Rect.fromCenter(
            center: Offset(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2,
            ),
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
          );

    await Share.share(shareMessage, sharePositionOrigin: shareOrigin);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final granted = await WalletService.instance.tryGrantShareReward(
          user.uid,
        );
        if (granted) {
          final wallet = await WalletService.instance.forceRefreshWallet(
            user.uid,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('free_scans_remaining', wallet.availableScans);
          final shareCoins = wallet.shareCoins;
          final coinEarningSharesToday = wallet.coinEarningSharesToday;
          final remainingSharesForCoins =
              UserWallet.maxCoinEarningSharesPerDay - coinEarningSharesToday;

          String message;
          if (remainingSharesForCoins <= 0) {
            message =
                "✅ Share recorded! You've reached today's limit (3 shares). Share again tomorrow to earn more coins!";
          } else {
            final coinsNeeded = 100 - shareCoins;
            final sharesNeeded = (coinsNeeded / 20).ceil();

            if (shareCoins >= 100) {
              message =
                  "🎉 +1 scan unlocked! You earned 100 coins from sharing!";
            } else {
              message =
                  "🎁 +20 coins earned! ($shareCoins/100 coins) $remainingSharesForCoins share${remainingSharesForCoins > 1 ? 's' : ''} left today to earn coins!";
            }
          }

          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: remainingSharesForCoins <= 0
                ? Colors.orange
                : const Color(0xFF388E3C),
          );
        } else {
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

  Widget _placementControl() {
    return Consumer2<PlantProvider, LocationProvider>(
      builder: (context, plants, locations, _) {
        Plant live = widget.plant;
        for (final candidate in plants.favorites) {
          if (candidate.id == widget.plant.id) {
            live = candidate;
            break;
          }
        }
        final location = locations.forPlant(live);
        final label = live.placement == PlantWeatherContext.unknown
            ? 'Where does this one live?'
            : location == null
            ? live.placement.label
            : '${live.placement.label} · ${location.name}';
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => showPlantContextSheet(context, plant: live),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _howIsItDoingLine() {
    return Consumer2<RecoveryProvider, CareRuleProvider>(
      builder: (context, recovery, careRules, _) {
        final rules = careRules.rules
            .where((r) => r.plantId == widget.plant.id)
            .toList();
        final text = PlantDetailStatus.howIsItDoing(
          now: DateTime.now(),
          activeCase: recovery.activeCaseForPlant(widget.plant.id),
          careRules: rules,
        );
        return Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget infoCard({
      required String title,
      required Widget child,
      required IconData icon,
      Color? iconColor,
    }) {
      final color = iconColor ?? const Color(0xFF4CAF50);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildAboutTab() {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          infoCard(
            title: "This plant",
            icon: Icons.eco_outlined,
            child: HarvestablePlantControl(plant: widget.plant),
          ),
          if (widget.plant.description.isNotEmpty)
            infoCard(
              title: "Description",
              icon: Icons.article,
              child: Text(
                widget.plant.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ),
          if (widget.plant.taxonomy.isNotEmpty)
            infoCard(
              title: "Classification",
              icon: Icons.account_tree,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaxonomyRow(
                    "Kingdom",
                    widget.plant.taxonomy['kingdom'],
                  ),
                  _buildTaxonomyRow("Family", widget.plant.taxonomy['family']),
                  _buildTaxonomyRow("Genus", widget.plant.taxonomy['genus']),
                  _buildTaxonomyRow(
                    "Species",
                    widget.plant.taxonomy['species'],
                  ),
                ],
              ),
            ),
          if (widget.plant.nativeRegion.isNotEmpty)
            infoCard(
              title: "Native Region",
              icon: Icons.public,
              iconColor: const Color(0xFF2196F3),
              child: Text(
                widget.plant.nativeRegion,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          if (widget.plant.growthSeason.isNotEmpty)
            infoCard(
              title: "Growing Season",
              icon: Icons.wb_sunny,
              iconColor: const Color(0xFFFF9800),
              child: Text(
                widget.plant.growthSeason,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          if (widget.plant.careGuide.isNotEmpty)
            infoCard(
              title: "Care notes",
              icon: Icons.spa,
              iconColor: const Color(0xFF8BC34A),
              child: Column(
                children: [
                  _buildCareRow(
                    Icons.water_drop,
                    "Watering",
                    widget.plant.careGuide['watering'],
                  ),
                  _buildCareRow(
                    Icons.wb_sunny_outlined,
                    "Sunlight",
                    widget.plant.careGuide['sunlight'],
                  ),
                  _buildCareRow(
                    Icons.grass,
                    "Soil",
                    widget.plant.careGuide['soil'],
                  ),
                  _buildCareRow(
                    Icons.eco,
                    "Fertilization",
                    widget.plant.careGuide['fertilization'],
                  ),
                  _buildCareRow(
                    Icons.content_cut,
                    "Pruning",
                    widget.plant.careGuide['pruning'],
                  ),
                  _buildCareRow(
                    Icons.nature,
                    "Propagation",
                    widget.plant.careGuide['propagation'],
                  ),
                ],
              ),
            ),
          if (widget.plant.healthScan.isNotEmpty)
            infoCard(
              title: "Identification notes",
              icon: Icons.health_and_safety,
              iconColor: const Color(0xFF4CAF50),
              child: Text(
                widget.plant.healthScan,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
          IdentifySafetySummary(
            safety: PlantSafety.fromPlant(widget.plant),
            identificationUncertain:
                widget.plant.identityConfirmation != IdentityStatus.confirmed,
          ),
          const SizedBox(height: 8),
          if (widget.plant.commonPests.isNotEmpty ||
              widget.plant.commonDiseases.isNotEmpty)
            infoCard(
              title: "Common Issues",
              icon: Icons.bug_report,
              iconColor: const Color(0xFFE91E63),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.plant.commonPests.isNotEmpty) ...[
                    Text(
                      "Pests:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      widget.plant.commonPests,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (widget.plant.commonDiseases.isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (widget.plant.commonDiseases.isNotEmpty) ...[
                    Text(
                      "Diseases:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      widget.plant.commonDiseases,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.plant.usage.isNotEmpty)
            infoCard(
              title: "Uses",
              icon: Icons.local_pharmacy,
              iconColor: const Color(0xFF9C27B0),
              child: Text(
                widget.plant.usage,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          if (widget.plant.funFact.isNotEmpty)
            infoCard(
              title: "Did You Know?",
              icon: Icons.lightbulb_rounded,
              iconColor: const Color(0xFFFFC107),
              child: Text(
                widget.plant.funFact,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFFF8F00),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        title: Text(
          (widget.plant.name.isNotEmpty
              ? (widget.plant.name.length > 20
                    ? '${widget.plant.name.substring(0, 20)}...'
                    : widget.plant.name)
              : "Unknown Plant"),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Plant Name & Image Row (Compact)
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
                      child:
                          (widget.plant.imageFile != null &&
                              File(widget.plant.imageFile!.path).existsSync())
                          ? Image.file(
                              widget.plant.imageFile!,
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
                            IdentifyLogic.displayName(widget.plant),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.plant.scientificName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.plant.scientificName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (widget.plant.identityConfirmation !=
                              IdentityStatus.confirmed) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.plant.identityConfirmation ==
                                      IdentityStatus.likely
                                  ? 'Likely match'
                                  : 'Needs another look',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          _placementControl(),
                          const SizedBox(height: 4),
                          _howIsItDoingLine(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Consumer<PlantProvider>(
                builder: (context, plants, _) {
                  Plant live = widget.plant;
                  for (final candidate in plants.favorites) {
                    if (candidate.id == widget.plant.id) {
                      live = candidate;
                      break;
                    }
                  }
                  return PlantGrowCard(plant: live);
                },
              ),

              Consumer<RecoveryProvider>(
                builder: (context, recovery, _) {
                  final openCase = recovery.activeCaseForPlant(widget.plant.id);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Column(
                      children: [
                        if (openCase != null)
                          _recoveryBanner(context, recovery, openCase),
                        if (openCase == null)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlantDiagnosisScreen(
                                      plant: widget.plant,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                "Something's wrong?",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // Horizontal Tab Bar
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE3E9E2)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Color(0xFF1F6F35), width: 2),
                  ),
                  labelColor: const Color(0xFF1F6F35),
                  unselectedLabelColor: const Color(0xFF667068),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: PlantWorkspaceTabs.care),
                    Tab(text: PlantWorkspaceTabs.health),
                    Tab(text: PlantWorkspaceTabs.timeline),
                    Tab(text: PlantWorkspaceTabs.about),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    PlantCareTab(plant: widget.plant),
                    PlantHealthTab(plant: widget.plant),
                    PlantTimelineTab(plantId: widget.plant.id),
                    buildAboutTab(),
                  ],
                ),
              ),
            ],
          ),

          // Fixed Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE3E9E2)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      // Remove from Favorites
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            'Remove',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            final provider = Provider.of<PlantProvider>(
                              context,
                              listen: false,
                            );
                            provider.removeFromFavorites(widget.plant);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Removed!',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share
                      Expanded(
                        child: OutlinedButton.icon(
                          key: _shareButtonKey,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 1.5,
                            ),
                          ),
                          icon: const Icon(
                            Icons.share_rounded,
                            color: Color(0xFF4CAF50),
                            size: 18,
                          ),
                          label: Text(
                            'Share',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _sharePlant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Folder
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            color: Color(0xFF4CAF50),
                            size: 18,
                          ),
                          label: Text(
                            'Garden',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) =>
                                  AddToFolderDialog(plant: widget.plant),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoveryBanner(
    BuildContext context,
    RecoveryProvider recovery,
    RecoveryCase openCase,
  ) {
    final canUnknown = RecoveryLogic.canCloseAsUnknown(
      openCase,
      DateTime.now(),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recovery.checkBackSentence(openCase),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecoveryCheckInScreen(
                        recoveryCase: openCase,
                        plant: widget.plant,
                        stage: openCase.day3CompletedAt == null
                            ? CheckInStage.day3
                            : CheckInStage.day7,
                      ),
                    ),
                  );
                },
                child: const Text('Check in'),
              ),
              TextButton(
                onPressed: () => recovery.deferTreatment(openCase),
                child: const Text("I haven't got to it yet"),
              ),
              if (canUnknown)
                TextButton(
                  onPressed: () => recovery.closeCase(
                    recoveryCase: openCase,
                    result: OutcomeResult.unknown,
                    closeReason: 'missed_day3',
                  ),
                  child: const Text('Close as unknown'),
                ),
              TextButton(
                onPressed: () => recovery.closeCase(
                  recoveryCase: openCase,
                  result: OutcomeResult.lost,
                  closeReason: 'user_closed_lost',
                ),
                child: const Text('Plant did not make it'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxonomyRow(String label, String? value) {
    if (value?.isEmpty ?? true) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value!,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildCareRow(IconData icon, String label, String? value) {
    if (value?.isEmpty ?? true) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8BC34A)),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
