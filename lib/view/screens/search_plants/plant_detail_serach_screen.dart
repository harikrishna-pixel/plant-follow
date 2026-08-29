import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/services/gemini_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:plantidentifier/services/search_service.dart';

class PlantDetailSearchScreen extends StatefulWidget {
  final String plantName;
  final String scientificName;
  final String category;
  final String thumbnailUrl;

  const PlantDetailSearchScreen({
    super.key,
    required this.plantName,
    required this.scientificName,
    required this.category,
    required this.thumbnailUrl,
  });

  @override
  State<PlantDetailSearchScreen> createState() => _PlantDetailSearchScreenState();
}

class _PlantDetailSearchScreenState extends State<PlantDetailSearchScreen> {
  bool _isLoading = true;
  String _plantInfo = '';
  String _error = '';
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;
  static final RegExp _sectionHeadingPattern =
      RegExp(r'^(?:[^\w]*)\s*(Description|Care Tips|Benefits|Quick Note)\s*:?\s*(.*)$',
          caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _loadImages();
    _fetchPlantDetails();
  }
  
  Future<void> _loadImages() async {
    // Fetch 2-3 images for the plant
    final imageUrls = <String>[];
    
    // Add the thumbnail as first image
    if (widget.thumbnailUrl.isNotEmpty) {
      imageUrls.add(widget.thumbnailUrl);
    }
    
    // Fetch 2 more images from Unsplash
    try {
      for (int i = 0; i < 2; i++) {
        final imageUrl = await UnsplashImageService.getPlantImage(widget.plantName);
        if (imageUrl.isNotEmpty && !imageUrls.contains(imageUrl)) {
          imageUrls.add(imageUrl);
        }
      }
    } catch (e) {
      debugPrint('Error loading additional images: $e');
    }
    
    // Ensure we have at least the thumbnail
    if (imageUrls.isEmpty && widget.thumbnailUrl.isNotEmpty) {
      imageUrls.add(widget.thumbnailUrl);
    }
    
    if (mounted) {
      setState(() {
        _imageUrls = imageUrls;
      });
    }
  }

  /// Clean markdown formatting from Gemini response
  String _cleanMarkdown(String text) {
    // Remove asterisks (**, *, etc.)
    String cleaned = text.replaceAll(RegExp(r'\*+'), '');
    
    // Remove other common markdown symbols
    cleaned = cleaned.replaceAll(RegExp(r'#+\s'), ''); // Remove headers
    cleaned = cleaned.replaceAll(RegExp(r'`+'), ''); // Remove code blocks
    cleaned = cleaned.replaceAll(RegExp(r'_+'), ''); // Remove underscores
    
    // Clean up multiple spaces and newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 newlines
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' '); // Remove multiple spaces
    
    return cleaned.trim();
  }

  List<_PlantInfoSection> _parsePlantInfoSections(String info) {
    final sections = <_PlantInfoSection>[];
    String? currentTitle;
    final List<String> contentLines = [];

    void flushSection() {
      final body = contentLines.join('\n').trim();
      if (body.isEmpty) {
        contentLines.clear();
        return;
      }
      final title = currentTitle != null && currentTitle!.trim().isNotEmpty
          ? _formatSectionTitle(currentTitle!)
          : 'Details';
      sections.add(_PlantInfoSection(title: title, content: body));
      contentLines.clear();
    }

    for (final rawLine in info.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        contentLines.add('');
        continue;
      }
      final match = _sectionHeadingPattern.firstMatch(line);
      if (match != null) {
        flushSection();
        currentTitle = match.group(1);
        final remainder = match.group(2)?.trim() ?? '';
        if (remainder.isNotEmpty) {
          contentLines.add(remainder);
        }
      } else {
        contentLines.add(line);
      }
    }

    flushSection();

    if (sections.isEmpty && info.trim().isNotEmpty) {
      sections.add(_PlantInfoSection(title: 'Details', content: info.trim()));
    }

    return sections;
  }

  String _formatSectionTitle(String raw) {
    final normalized = raw.toLowerCase();
    switch (normalized) {
      case 'description':
        return 'Description';
      case 'care tips':
        return 'Care Tips';
      case 'benefits':
        return 'Benefits';
      case 'quick note':
        return 'Quick Note';
      default:
        return raw.trim().isEmpty ? 'Details' : raw.trim();
    }
  }

  Future<void> _fetchPlantDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final geminiService = GeminiService();
      final prompt = '''
Provide a brief, user-friendly overview of ${widget.plantName} (${widget.scientificName}).

Include ONLY these sections in a concise format (2-3 sentences each):

🌿 Description: What it looks like and basic characteristics

💧 Care Tips: Watering, sunlight, and soil needs

🌱 Benefits: Why grow this plant

⚠️ Quick Note: Any important warnings or tips

Keep it simple and friendly!''';

      final response = await geminiService.generateContent(prompt);
      
      if (mounted) {
        setState(() {
          _plantInfo = _cleanMarkdown(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load plant details. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Slider
          SliverAppBar(
            expandedHeight: 300.h,
            floating: true,
            pinned: false,
            snap: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B5E20), size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _imageUrls.isEmpty
                  ? Container(
                      color: const Color(0xFFE8F5E9),
                      child: const Center(
                        child: Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 80),
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          itemCount: _imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              _imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8F5E9),
                                child: const Center(
                                  child: Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 80),
                                ),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFFE8F5E9),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // Page indicators
                        if (_imageUrls.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _imageUrls.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (_) {
                        final hasScientificName = widget.scientificName.trim().isNotEmpty;
                        final hasCategory = widget.category.trim().isNotEmpty;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.plantName,
                              style: GoogleFonts.poppins(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            SizedBox(height: hasScientificName ? 6.h : 12.h),
                            if (hasScientificName)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.scientificName,
                                    style: GoogleFonts.inter(
                                      fontSize: 15.sp,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                ],
                              ),
                            if (hasCategory)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.category, color: Color(0xFF4CAF50), size: 16),
                                    SizedBox(width: 6.w),
                                    Text(
                                      widget.category,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 24.h),
                          ],
                        );
                      },
                    ),

                    // Divider
                    Divider(color: Colors.grey[300], height: 1),
                    SizedBox(height: 24.h),

                    // Plant Information
                    if (_isLoading)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Loading plant details...',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_error.isNotEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            SizedBox(height: 12.h),
                            Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _fetchPlantDetails,
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Builder(
                        builder: (_) {
                          final sections = _parsePlantInfoSections(_plantInfo);
                          return Column(
                            children: [
                              for (int i = 0; i < sections.length; i++)
                                Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 16.h),
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FDF8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sections[i].title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1B5E20),
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        sections[i].content,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          color: Colors.black87,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantInfoSection {
  final String title;
  final String content;

  const _PlantInfoSection({required this.title, required this.content});
}

