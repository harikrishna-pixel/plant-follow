import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:plantidentifier/view/screens/result_screens/result_screen_dialogs.dart';
import 'package:provider/provider.dart';
import '../../model/data_model/plant_model.dart';
import '../../provider/plant_provider.dart';
import '../../provider/plant_history_provider.dart';
import '../../provider/folder_provider.dart';
import '../../navigation/plant_workspace_tabs.dart';
import '../../services/identification_analytics.dart';
import '../../services/identification_result.dart';
import '../../services/identify_logic.dart';
import 'scan_screen.dart';
import 'reminder/add_reminder_dialog.dart';
import 'favourite_screen/folder_detail_screen.dart';
import 'favourite_screen/plant_care_tab.dart';
import 'favourite_screen/plant_health_tab.dart';
import 'favourite_screen/plant_timeline_tab.dart';
import 'plant_context/plant_context_sheet.dart';
import 'result_screens/identify_trust_card.dart';


class ResultScreen extends StatefulWidget {
  final Plant plant;
  final IdentificationResult? identification;
  const ResultScreen({
    super.key,
    required this.plant,
    this.identification,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  FlutterTts? _flutterTts;
  bool _isSpeaking = false;
  int _currentSpokenLine = -1;
  List<Map<String, String>> _availableVoices = [];
  String _selectedVoice = '';
  late TabController _tabController;
  late final ScrollController _scrollController;
  int _selectedTabIndex = 0;
  bool _isScrolled = false;
  final GlobalKey _shareButtonKey = GlobalKey();
  List<String> _relatedImages = [];
  bool _isLoadingRelatedImages = false;
  late Plant _plant;
  late IdentificationResult _trust;
  String _confirmationSource = 'model';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _trust = widget.identification ?? IdentificationResult.fromPlant(widget.plant);
    _confirmationSource = _trust.confirmationSource ?? 'model';
    _tabController = TabController(length: PlantWorkspaceTabs.labels.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _initTts();
    _saveToHistory();
    _loadRelatedImages();
  }

  Future<void> _loadRelatedImages() async {
    setState(() {
      _isLoadingRelatedImages = true;
    });

    try {
      final plantName = _plant.name;
      final scientificName = _plant.scientificName ?? '';
      
      // Use both common name and scientific name for better results
      final searchQuery = scientificName.isNotEmpty 
          ? '$plantName $scientificName'
          : plantName;
      
      final images = await _fetchRelatedImagesFromUnsplash(searchQuery);
      
      if (mounted) {
        setState(() {
          _relatedImages = images;
          _isLoadingRelatedImages = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading related images: $e');
      if (mounted) {
        setState(() {
          _isLoadingRelatedImages = false;
        });
      }
    }
  }

  Future<List<String>> _fetchRelatedImagesFromUnsplash(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent('$query plant nature');
      final url = 'https://api.unsplash.com/search/photos?query=$encodedQuery&per_page=4&orientation=landscape';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Client-ID hYjjb0Q9x9sUu5B1BpIkgd1B8fvP00QmDMARhXLGprE'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final List<String> imageUrls = [];
          for (var result in data['results']) {
            final imageUrl = result['urls']?['regular'] ?? '';
            if (imageUrl.isNotEmpty) {
              imageUrls.add(imageUrl);
            }
          }
          return imageUrls;
        }
      }
    } catch (e) {
      debugPrint('Error fetching related images: $e');
    }
    return [];
  }

  void _showFullScreenImage(String imageUrl, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _FullScreenImageViewer(
        imageUrls: _relatedImages,
        initialIndex: initialIndex,
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final isScrolled = _scrollController.offset > 80;
    if (isScrolled != _isScrolled && mounted) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  // Save scanned plant to history. Unconfirmed results are not successful IDs.
  void _saveToHistory() {
    if (!IdentifyLogic.mayRecordScanHistory(_plant)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final historyProvider = Provider.of<PlantHistoryProvider>(context, listen: false);
      historyProvider.addToHistory(_plant);
    });
  }

  void _retryIdentification() {
    IdentificationAnalytics.retry();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  void _selectAlternative(IdentifyCandidate candidate) {
    IdentificationAnalytics.alternativeSelected();
    setState(() {
      _plant = IdentifyLogic.applyCandidate(_plant, candidate);
      _trust = _trust.withSelectedCandidate(candidate);
      _confirmationSource = 'user_selected';
    });
    if (IdentifyLogic.mayRecordScanHistory(_plant)) {
      Provider.of<PlantHistoryProvider>(context, listen: false)
          .addToHistory(_plant);
    }
  }

  Future<void> _savePlant(PlantProvider provider) async {
    if (_saving || !_trust.allowsDirectSave) return;
    setState(() => _saving = true);
    final success = await provider.saveFavorite(
      _plant,
      confirmationSource: _confirmationSource,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      IdentificationAnalytics.plantSaved(
        identityStatus: _plant.identityConfirmation,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Saved!', style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await showPlantContextSheet(
        context,
        plant: _plant,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('Already saved', style: GoogleFonts.poppins(fontSize: 13)),
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

  _initTts() async {
    // Stop and dispose any existing TTS instance
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _flutterTts = null;
    }
    
    _flutterTts = FlutterTts();

    // Get available voices
    var voices = await _flutterTts!.getVoices;
    if (voices != null) {
      // Filter for English voices only and remove duplicates
      final allVoices = List<Map<String, String>>.from(
        voices.map((voice) => Map<String, String>.from(voice)),
      );
      
      // Filter English voices only
      final englishVoices = allVoices.where((voice) {
        final locale = voice['locale']?.toLowerCase() ?? '';
        return locale.startsWith('en');
      }).toList();
      
      // Remove duplicates based on voice name
      final uniqueVoices = <String, Map<String, String>>{};
      for (var voice in englishVoices) {
        final name = voice['name'] ?? '';
        if (name.isNotEmpty && !uniqueVoices.containsKey(name)) {
          uniqueVoices[name] = voice;
        }
      }
      
      // Convert to list and sort alphabetically
      final allUniqueVoices = uniqueVoices.values.toList();
      allUniqueVoices.sort((a, b) {
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });
      
      // List of voices to exclude
      final excludedVoices = ['superstar', 'trinold'];
      
      // Filter voices from "Rishi" to "Samantha" (alphabetically) and exclude unwanted voices
      var filteredVoices = allUniqueVoices.where((voice) {
        final name = (voice['name'] ?? '').toLowerCase();
        final isInRange = name.compareTo('rishi') >= 0 && name.compareTo('samantha') <= 0;
        final isExcluded = excludedVoices.contains(name);
        return isInRange && !isExcluded;
      }).toList();
      
      // If we have less than 5 voices, expand the range to ensure at least 5 voices
      if (filteredVoices.length < 5 && allUniqueVoices.length >= 5) {
        // Find the index of voices around Rishi and Samantha
        int rishiIndex = -1;
        int samanthaIndex = -1;
        
        for (int i = 0; i < allUniqueVoices.length; i++) {
          final name = (allUniqueVoices[i]['name'] ?? '').toLowerCase();
          if (rishiIndex == -1 && name.compareTo('rishi') >= 0) {
            rishiIndex = i;
          }
          if (name.compareTo('samantha') <= 0) {
            samanthaIndex = i;
          }
        }
        
        // If we found indices, expand the range
        if (rishiIndex != -1) {
          // Take voices starting from Rishi index, ensuring we get at least 5 (excluding unwanted)
          final startIndex = rishiIndex;
          final endIndex = allUniqueVoices.length;
          filteredVoices = allUniqueVoices
              .sublist(startIndex, endIndex)
              .where((voice) {
                final name = (voice['name'] ?? '').toLowerCase();
                return !excludedVoices.contains(name);
              })
              .take(5)
              .toList();
        } else {
          // If Rishi not found, take first voices that are >= Rishi alphabetically (excluding unwanted)
          filteredVoices = allUniqueVoices
              .where((voice) {
                final name = (voice['name'] ?? '').toLowerCase();
                return name.compareTo('rishi') >= 0 && !excludedVoices.contains(name);
              })
              .take(5)
              .toList();
        }
        
        // If still less than 5, take voices from the sorted list excluding unwanted ones
        if (filteredVoices.length < 5) {
          filteredVoices = allUniqueVoices
              .where((voice) {
                final name = (voice['name'] ?? '').toLowerCase();
                return !excludedVoices.contains(name);
              })
              .take(5)
              .toList();
        }
      }
      
      setState(() {
        _availableVoices = filteredVoices;
        if (_availableVoices.isNotEmpty) {
          _selectedVoice = _availableVoices.first['name'] ?? '';
        }
      });
    }

    // Set up TTS settings
    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    // Listen to completion - only set once
    _flutterTts!.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentSpokenLine = -1;
        });
      }
    });
  }

  List<String> _composeLines(Plant plant) {
    final lines = <String>[];
    lines.add("Plant Name: ${plant.name}");
    if ((plant.scientificName ?? '').isNotEmpty) {
      lines.add("Scientific Name: ${plant.scientificName}");
    }
    if ((plant.description ?? '').isNotEmpty) {
      lines.add("Description: ${plant.description}");
    }
    if ((plant.taxonomy ?? {}).isNotEmpty) {
      lines.add(
        "Classification: "
            "Kingdom: ${plant.taxonomy['kingdom']}, "
            "Family: ${plant.taxonomy['family']}, "
            "Genus: ${plant.taxonomy['genus']}, "
            "Species: ${plant.taxonomy['species']}",
      );
    }
    if ((plant.nativeRegion ?? '').isNotEmpty) {
      lines.add("Native Region: ${plant.nativeRegion}");
    }
    if ((plant.growthSeason ?? '').isNotEmpty) {
      lines.add("Growing Season: ${plant.growthSeason}");
    }
    if ((plant.toxicity ?? '').isNotEmpty) {
      lines.add("Toxicity: ${plant.toxicity}");
    }
    if ((plant.careGuide ?? {}).isNotEmpty) {
      lines.add(
        "Care Guide: "
            "Watering: ${plant.careGuide['watering']}, "
            "Sunlight: ${plant.careGuide['sunlight']}, "
            "Soil: ${plant.careGuide['soil']}, "
            "Fertilization: ${plant.careGuide['fertilization']}, "
            "Pruning: ${plant.careGuide['pruning']}, "
            "Propagation: ${plant.careGuide['propagation']}",
      );
    }
    if ((plant.healthScan ?? '').isNotEmpty) {
      lines.add("Health Status: ${plant.healthScan}");
    }
    if ((plant.commonPests ?? '').isNotEmpty) {
      lines.add("Common Pests: ${plant.commonPests}");
    }
    if ((plant.commonDiseases ?? '').isNotEmpty) {
      lines.add("Common Diseases: ${plant.commonDiseases}");
    }
    if ((plant.usage ?? '').isNotEmpty) lines.add("Uses: ${plant.usage}");
    if ((plant.funFact ?? '').isNotEmpty) {
      lines.add("Fun Fact: ${plant.funFact}");
    }
    return lines.where((l) => l.trim().isNotEmpty).toList();
  }

  /// Flutter TTS Implementation with proper voice selection
  Future<void> _speakPlantDetails(BuildContext context) async {
    // Stop any ongoing speech first
    if (_isSpeaking) {
      await _flutterTts?.stop();
      setState(() {
        _isSpeaking = false;
        _currentSpokenLine = -1;
      });
      return;
    }
    
    // Ensure TTS is completely stopped before starting new speech
    await _flutterTts?.stop();

    setState(() {
      _isSpeaking = true;
      _currentSpokenLine = -1;
    });

    final lines = _composeLines(_plant);

    // Set selected voice properly
    if (_selectedVoice.isNotEmpty && _availableVoices.isNotEmpty) {
      // Find the complete voice object
      var selectedVoiceObject = _availableVoices.firstWhere(
            (voice) => voice['name'] == _selectedVoice,
        orElse: () => _availableVoices.first,
      );

      // Set voice with both name and locale
      await _flutterTts!.setVoice({
        "name": selectedVoiceObject['name'] ?? _selectedVoice,
        "locale": selectedVoiceObject['locale'] ?? "en-US",
      });
    }

    String fullText = lines.join(". ");

    try {
      await _flutterTts!.speak(fullText);
    } catch (e) {
      setState(() {
        _isSpeaking = false;
        _currentSpokenLine = -1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Text-to-Speech error: Please check device settings"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showVoiceOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.record_voice_over,
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
                            'Voice Assistant',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          Text(
                            _selectedVoice.isNotEmpty ? _selectedVoice : "Default Voice",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Change Voice button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showVoiceSelector();
                        },
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(
                          'Change Voice',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Play/Stop button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _speakPlantDetails(context);
                        },
                        icon: Icon(
                          _isSpeaking ? Icons.stop : Icons.play_arrow,
                          size: 18,
                        ),
                        label: Text(
                          _isSpeaking ? 'Stop' : 'Play',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSpeaking
                              ? const Color(0xFFF44336)
                              : const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Voice',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
            if (_availableVoices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No voices available on this device"),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _availableVoices.length,
                  itemBuilder: (context, index) {
                    final voice = _availableVoices[index];
                    final voiceName = voice['name'] ?? '';
                    final voiceLocale = voice['locale'] ?? '';
                    final isSelected = voiceName == _selectedVoice;

                    return ListTile(
                      title: Text(
                        voiceName,
                        style: GoogleFonts.inter(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        voiceLocale,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                      )
                          : null,
                      onTap: () async {
                        setState(() {
                          _selectedVoice = voiceName;
                        });

                        // Test the voice immediately
                        try {
                          await _flutterTts!.setVoice({
                            "name": voiceName,
                            "locale": voiceLocale,
                          });

                          // Optional: speak a test phrase
                          await _flutterTts!.speak(
                            "Voice changed. Tap Play to Listen ",
                          );
                        } catch (e) {
                          print("Error setting voice: $e");
                        }

                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Properly stop and dispose TTS
    _flutterTts?.stop();
    _flutterTts = null;
    _tabController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sharePlant(BuildContext context) async {
    const appStoreLink = 'https://apps.apple.com/app/id/6752886333';
    
    final shareMessage = '''
🌿 ${_plant.name}
${_plant.scientificName?.isNotEmpty == true ? '🔬 ${_plant.scientificName}\n' : ''}
${_plant.description?.isNotEmpty == true ? '${_plant.description}\n\n' : ''}
Shared from PlantFollow
📱 Download the app: $appStoreLink
''';
    
    final renderBox = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
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

    await Share.share(
      shareMessage,
      sharePositionOrigin: shareOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlantProvider>(context, listen: false);

    Widget infoCard({
      required String title,
      required Widget child,
      required IconData icon,
      Color? iconColor,
    }) {
      final color = iconColor ?? const Color(0xFF4CAF50);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.all(12),
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

    Widget _emptyState(IconData icon, String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      ),
    );

    Widget buildBasicInfoTab(List<String> lines) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 120),
        physics: const BouncingScrollPhysics(),
        primary: false,
        children: [
          infoCard(
            title: "Plant Name",
            icon: Icons.park,
            child: _buildSpeechLine(context, line: "Plant Name: ${_plant.name}",
                lineIndex: lines.indexWhere((l) => l == "Plant Name: ${_plant.name}")),
          ),
          if ((_plant.scientificName ?? '').isNotEmpty)
            infoCard(
              title: "Scientific Name",
              icon: Icons.science,
              child: _buildSpeechLine(context, line: "Scientific Name: ${_plant.scientificName}",
                  lineIndex: lines.indexWhere((l) => l == "Scientific Name: ${_plant.scientificName}"), italic: true),
            ),
          if ((_plant.description ?? '').isNotEmpty)
            infoCard(
              title: "Description",
              icon: Icons.article,
              child: _buildSpeechLine(context, line: "Description: ${_plant.description}",
                  lineIndex: lines.indexWhere((l) => l == "Description: ${_plant.description}")),
            ),
          if ((_plant.taxonomy ?? {}).isNotEmpty)
            infoCard(
              title: "Classification",
              icon: Icons.account_tree,
              child: _buildSpeechLine(context,
                  line: "Classification: Kingdom: ${_plant.taxonomy?['kingdom']}, Family: ${_plant.taxonomy?['family']}, Genus: ${_plant.taxonomy?['genus']}, Species: ${_plant.taxonomy?['species']}",
                  lineIndex: lines.indexWhere((l) => l.startsWith("Classification: Kingdom:"))),
            ),
          if ((_plant.nativeRegion ?? '').isNotEmpty)
            infoCard(
              title: "Native Region",
              icon: Icons.public,
              iconColor: const Color(0xFF2196F3),
              child: _buildSpeechLine(context, line: "Native Region: ${_plant.nativeRegion}",
                  lineIndex: lines.indexWhere((l) => l == "Native Region: ${_plant.nativeRegion}")),
            ),
        ],
      );
    }

    Widget buildCareGrowthTab(List<String> lines) {
      final hasContent = (_plant.growthSeason ?? '').isNotEmpty || (_plant.careGuide ?? {}).isNotEmpty;
      if (!hasContent) return _emptyState(Icons.spa, 'No care information available');

      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 120),
        physics: const BouncingScrollPhysics(),
        primary: false,
        children: [
          if ((_plant.growthSeason ?? '').isNotEmpty)
            infoCard(
              title: "Growing Season",
              icon: Icons.wb_sunny,
              iconColor: const Color(0xFFFF9800),
              child: _buildSpeechLine(context, line: "Growing Season: ${_plant.growthSeason}",
                  lineIndex: lines.indexWhere((l) => l == "Growing Season: ${_plant.growthSeason}")),
            ),
          if ((_plant.careGuide ?? {}).isNotEmpty)
            infoCard(
              title: "Care Guide",
              icon: Icons.spa,
              iconColor: const Color(0xFF8BC34A),
              child: _buildSpeechLine(context,
                  line: "Care Guide: Watering: ${_plant.careGuide?['watering']}, Sunlight: ${_plant.careGuide?['sunlight']}, Soil: ${_plant.careGuide?['soil']}, Fertilization: ${_plant.careGuide?['fertilization']}, Pruning: ${_plant.careGuide?['pruning']}, Propagation: ${_plant.careGuide?['propagation']}",
                  lineIndex: lines.indexWhere((l) => l.startsWith("Care Guide: Watering:"))),
            ),
        ],
      );
    }

    Widget buildHealthSafetyTab(List<String> lines) {
      final hasContent = (_plant.healthScan ?? '').isNotEmpty ||
          (_plant.toxicity ?? '').isNotEmpty ||
          (_plant.commonPests ?? '').isNotEmpty ||
          (_plant.commonDiseases ?? '').isNotEmpty;
      if (!hasContent) return _emptyState(Icons.health_and_safety, 'No health information available');

      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 120),
        physics: const BouncingScrollPhysics(),
        primary: false,
        children: [
          if ((_plant.healthScan ?? '').isNotEmpty)
            infoCard(
              title: "Health Status",
              icon: Icons.health_and_safety,
              iconColor: const Color(0xFF4CAF50),
              child: _buildSpeechLine(context, line: "Health Status: ${_plant.healthScan}",
                  lineIndex: lines.indexWhere((l) => l == "Health Status: ${_plant.healthScan}"),
                  container: true, containerColor: const Color(0xFFE8F5E8), textColor: const Color(0xFF2E7D32)),
            ),
          if ((_plant.toxicity ?? '').isNotEmpty)
            infoCard(
              title: "Safety Information",
              icon: Icons.warning_rounded,
              iconColor: const Color(0xFFF44336),
              child: _buildSpeechLine(context, line: "Toxicity: ${_plant.toxicity}",
                  lineIndex: lines.indexWhere((l) => l == "Toxicity: ${_plant.toxicity}"),
                  container: true, containerColor: const Color(0xFFFFF3E0), textColor: const Color(0xFFE65100)),
            ),
          if ((_plant.commonPests ?? '').isNotEmpty || (_plant.commonDiseases ?? '').isNotEmpty)
            infoCard(
              title: "Common Issues",
              icon: Icons.bug_report,
              iconColor: const Color(0xFFE91E63),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((_plant.commonPests ?? '').isNotEmpty)
                    _buildSpeechLine(context, line: "Common Pests: ${_plant.commonPests}",
                        lineIndex: lines.indexWhere((l) => l == "Common Pests: ${_plant.commonPests}")),
                  if ((_plant.commonDiseases ?? '').isNotEmpty)
                    _buildSpeechLine(context, line: "Common Diseases: ${_plant.commonDiseases}",
                        lineIndex: lines.indexWhere((l) => l == "Common Diseases: ${_plant.commonDiseases}")),
                ],
              ),
            ),
        ],
      );
    }

    Widget buildAdditionalInfoTab(List<String> lines) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 120),
        physics: const BouncingScrollPhysics(),
        primary: false,
        children: [
          IdentifySafetySummary(
            safety: _trust.safety,
            identificationUncertain: _trust.identificationUncertain,
          ),
          const SizedBox(height: 12),
          if ((_plant.healthScan ?? '').isNotEmpty)
            infoCard(
              title: "Identification notes",
              icon: Icons.notes_outlined,
              iconColor: const Color(0xFF4CAF50),
              child: _buildSpeechLine(
                context,
                line: "Identification notes: ${_plant.healthScan}",
                lineIndex: lines.indexWhere(
                  (l) => l == "Identification notes: ${_plant.healthScan}",
                ),
              ),
            ),
          if ((_plant.usage ?? '').isNotEmpty)
            infoCard(
              title: "Uses",
              icon: Icons.local_pharmacy,
              iconColor: const Color(0xFF9C27B0),
              child: _buildSpeechLine(context, line: "Uses: ${_plant.usage}",
                  lineIndex: lines.indexWhere((l) => l == "Uses: ${_plant.usage}")),
            ),
          if ((_plant.funFact ?? '').isNotEmpty)
            infoCard(
              title: "Did You Know?",
              icon: Icons.lightbulb_rounded,
              iconColor: const Color(0xFFFFC107),
              child: _buildSpeechLine(context, line: "Fun Fact: ${_plant.funFact}",
                  lineIndex: lines.indexWhere((l) => l == "Fun Fact: ${_plant.funFact}"),
                  container: true, containerColor: const Color(0xFFFFF8E1), textColor: const Color(0xFFFF8F00)),
            ),
        ],
      );
    }

    List<String> lines = _composeLines(_plant);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        title: Text(
          'Plant Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Voice Assistant Button
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.stop_circle : Icons.record_voice_over,
              color: _isSpeaking ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
              size: 26,
            ),
            onPressed: () {
              if (_isSpeaking) {
                // If speaking, stop it
                _speakPlantDetails(context);
              } else {
                // Show voice options bottom sheet
                _showVoiceOptionsBottomSheet(context);
              }
            },
            tooltip: _isSpeaking ? 'Stop Voice' : 'Voice Assistant',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: const SizedBox.shrink(),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isScrolled
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('plant_header'),
                            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: (_plant.imageFile != null &&
                                          File(_plant.imageFile!.path).existsSync())
                                      ? Image.file(
                                          _plant.imageFile!,
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
                                Expanded(
                                  child: IdentifyTrustCard(
                                    plant: _plant,
                                    result: _trust,
                                    onRetry: _retryIdentification,
                                    onSelectAlternative: _selectAlternative,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: IdentifyTrustExtras(
                    result: _trust,
                    onRetry: _retryIdentification,
                    onSelectAlternative: _selectAlternative,
                  ),
                ),
                // Related Images Slider
                if (_relatedImages.isNotEmpty || _isLoadingRelatedImages)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text(
                              'Related Images',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 180,
                            child: _isLoadingRelatedImages
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    itemCount: _relatedImages.length,
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        onTap: () {
                                          _showFullScreenImage(_relatedImages[index], index);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 12),
                                          width: 160,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              _relatedImages[index],
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  color: const Color(0xFFE8F5E8),
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                              loadingProgress.expectedTotalBytes!
                                                          : null,
                                                      strokeWidth: 2,
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: const Color(0xFFE8F5E8),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.local_florist,
                                                      color: Color(0xFF4CAF50),
                                                      size: 40,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPersistentHeader(
                  pinned: true,
                  // floating: true,
                  delegate: _TabBarHeaderDelegate(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withOpacity(0.05),
                            const Color(0xFF81C784).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: _isScrolled
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: const Color(0xFF4CAF50).withOpacity(0.3),
                          //     blurRadius: 8,
                          //     offset: const Offset(0, 2),
                          //   ),
                          // ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF2E7D32),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.spa, size: 16),
                            text: PlantWorkspaceTabs.care,
                          ),
                          Tab(
                            icon: const Icon(Icons.health_and_safety, size: 16),
                            text: PlantWorkspaceTabs.health,
                          ),
                          Tab(
                            icon: const Icon(Icons.timeline, size: 16),
                            text: PlantWorkspaceTabs.timeline,
                          ),
                          Tab(
                            icon: const Icon(Icons.info_outline, size: 16),
                            text: PlantWorkspaceTabs.about,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                PlantCareTab(plant: _plant),
                PlantHealthTab(plant: _plant),
                PlantTimelineTab(plantId: _plant.id),
                buildAdditionalInfoTab(lines),
              ],
            ),
          ),

          // Fixed Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, const Color(0xFFF1F8F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: _trust.allowsDirectSave
                        ? [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                key: const Key('identify_primary_action'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
                                label: Text(
                                  _trust.primaryActionLabel,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: _saving ? null : () => _savePlant(provider),
                              ),
                            ),
                            if (_trust.identityStatus == IdentityStatus.likely) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  key: const Key('identify_retry'),
                                  onPressed: _retryIdentification,
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
                                  child: Text(
                                    IdentifyLogic.retryAction,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                                  ),
                                  icon: const Icon(Icons.folder_open, color: Color(0xFF2196F3), size: 18),
                                  label: Text(
                                    'Garden',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2196F3),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () => ResultScreenDialogs.showAddToFolderDialog(context, _plant),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  key: _shareButtonKey,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                  ),
                                  icon: const Icon(Icons.share_rounded, color: Color(0xFF4CAF50), size: 18),
                                  label: Text(
                                    'Share',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () => _sharePlant(context),
                                ),
                              ),
                            ],
                          ]
                        : [
                            Expanded(
                              child: ElevatedButton(
                                key: const Key('identify_primary_action'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _retryIdentification,
                                child: Text(
                                  IdentifyLogic.retryAction,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
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

  Widget _buildSpeechLine(
      BuildContext context, {
        required String line,
        required int lineIndex,
        bool italic = false,
        bool container = false,
        Color? containerColor,
        Color? textColor,
      }) {
    final isSpoken = lineIndex == _currentSpokenLine && _isSpeaking;
    Widget text = Text(
      line.replaceAll(RegExp(r'^\w+: '), ''),
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: isSpoken
            ? const Color(0xFF4CAF50)
            : (textColor ?? Colors.grey[800]),
        fontWeight: isSpoken ? FontWeight.bold : FontWeight.normal,
        backgroundColor: isSpoken
            ? const Color(0xFF4CAF50).withOpacity(0.08)
            : Colors.transparent,
      ),
    );
    if (container) {
      text = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSpoken
              ? const Color(0xFF4CAF50).withOpacity(0.13)
              : (containerColor ?? Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: text,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isSpoken ? const Color(0xFF4CAF50).withOpacity(0.06) : null,
      child: text,
    );
  }

  Widget buildReminderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      primary: false,
      children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF66BB6A).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 40,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Set Plant Care Reminders',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Never forget to water, fertilize, or care for your ${_plant.name}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Add Reminder Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddReminderDialog(
                    initialPlantName: _plant.name,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
              label: Text(
                'Add New Reminder',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Reminder Types Info
          Text(
            'Reminder Types',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 12),

          _buildReminderTypeCard(
            Icons.water_drop,
            'Watering',
            'Set regular watering schedules',
            const Color(0xFF2196F3),
          ),
          const SizedBox(height: 8),
          _buildReminderTypeCard(
            Icons.eco,
            'Fertilizing',
            'Remember to add nutrients',
            const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 8),
          _buildReminderTypeCard(
            Icons.terrain,
            'Soil Check',
            'Monitor soil conditions',
            const Color(0xFF795548),
          ),
          const SizedBox(height: 8),
          _buildReminderTypeCard(
            Icons.content_cut,
            'Pruning',
            'Trim and maintain growth',
            const Color(0xFFFF5722),
          ),
          const SizedBox(height: 8),
          _buildReminderTypeCard(
            Icons.move_up,
            'Repotting',
            'Change pots when needed',
            const Color(0xFF9C27B0),
          ),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      );
  }

  Widget _buildReminderTypeCard(
      IconData icon,
      String title,
      String description,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _TabBarHeaderDelegate({
    required this.child,
    this.height = 72,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Full screen image viewer
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Page indicator
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
