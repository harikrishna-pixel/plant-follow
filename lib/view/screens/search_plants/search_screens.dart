import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/view/screens/search_plants/plant_detail_serach_screen.dart';

import '../../../model/data_model/plant_search_result.dart';
import '../../../services/gemini_service.dart';
import '../../../services/search_service.dart';
import '../../../mixpanel/mixpanel.dart';

class SearchScreens extends StatefulWidget {
  const SearchScreens({super.key});

  @override
  State<SearchScreens> createState() => _SearchScreensState();
}

class _SearchScreensState extends State<SearchScreens> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  bool _isSearchLoading = false;
  PlantSearchResult? _searchResult;
  String? _searchError;
  late AnimationController _animationController;
  final GlobalKey<_SearchBarState> _searchBarKey = GlobalKey<_SearchBarState>();

  @override
  void initState() {
    super.initState();
    // Track Search Screen view
    MixpanelService.trackSearchScreen();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(); // Repeat the animation infinitely
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearchLoading = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final result = await _searchPlants(query.trim()).timeout(
        const Duration(seconds: 95),
      );
      
      if (!mounted) return;

      setState(() {
        _isSearchLoading = false;
        _searchResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSearchLoading = false;
        _searchError = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to search plants. Please try again.',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<PlantSearchResult> _searchPlants(String query) async {
    final geminiService = GeminiService();
    
    final prompt = '''You are a botany expert assistant. The user is searching for: $query

Return information about ONLY ONE plant that matches this search query. Be very specific and accurate with the plant name.

Return pure JSON (no markdown) with the following structure:
{
  "city": "",
  "temperature": 0,
  "categories": [],
  "plants": [
    {
      "name": string,
      "scientific_name": string,
      "category": string,
      "description": string,
      "image_url": ""
    }
  ]
}

IMPORTANT RULES:
- Return ONLY ONE plant in the plants array
- Return EMPTY categories array (no categories)
- The plant name must be the exact common name for "$query"
- Include the accurate scientific name
- ALWAYS leave image_url as empty string "" - images will be fetched separately
- Focus on accurate plant names, scientific names, and descriptions
- Do not include markdown, explanations, or trailing text
- Return only valid JSON
- If the search query is a specific plant name (like "Neem"), return that exact plant

Example response:
{
  "city": "",
  "temperature": 0,
  "categories": [],
  "plants": [
    {"name": "Neem", "scientific_name": "Azadirachta indica", "category": "Tree", "description": "Medicinal tree native to India", "image_url": ""}
  ]
}''';

    final response = await geminiService.generateContent(prompt);
    
    // Extract JSON from response
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
    if (match == null) {
      throw Exception('Could not parse search results');
    }

    final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    var result = PlantSearchResult.fromJson(decoded);

    // Fetch image from Unsplash using plant name and scientific name for better accuracy
    final updatedPlants = <PlantSummary>[];
    if (result.plants.isNotEmpty) {
      final plant = result.plants[0]; // Only process the first plant
      // Use both plant name and scientific name to get more accurate image
      // This helps distinguish between similar plants (e.g., Neem vs Moringa)
      final imageSearchQuery = '${plant.name} ${plant.scientificName}';
      final imageUrl = await UnsplashImageService.getPlantImage(imageSearchQuery);
      updatedPlants.add(PlantSummary(
        name: plant.name,
        scientificName: plant.scientificName,
        category: plant.category,
        imageUrl: imageUrl,
        description: plant.description,
      ));
    }
    
    return PlantSearchResult(
      city: result.city,
      temperature: result.temperature,
      categories: [], // No categories
      plants: updatedPlants,
    );
  }


  List<PlantCategory> _filterCategories(List<PlantCategory> categories) {
    if (_searchQuery.isEmpty) return categories;
    return categories.where((category) {
      return category.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<PlantSummary> _filterPlants(List<PlantSummary> plants) {
    if (_searchQuery.isEmpty) return plants;
    return plants.where((plant) {
      return plant.displayName.toLowerCase().contains(_searchQuery) ||
             plant.scientificName.toLowerCase().contains(_searchQuery) ||
             plant.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Search Plants',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF172019),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_isSearchLoading) {
            return _buildBeautifulLoadingAnimation();
          }

          if (_searchError != null && _searchResult == null) {
            return _ErrorState(
              message: 'Check your internet connection',
              onRetry: () async{
                if (_searchQuery.isNotEmpty) {
                  _performSearch(_searchQuery);
                }
              },
            );
          }

          // Show search bar initially if no results
          if (_searchResult == null) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: _SearchBar(
                      key: _searchBarKey,
                      onSearchChanged: _updateSearchQuery,
                      onSearch: _performSearch,
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchEmptyState(
                    onSearch: _performSearch,
                  ),
                ),
              ],
            );
          }

          final data = _searchResult!;
          final filteredCategories = _filterCategories(data.categories);
          final filteredPlants = _filterPlants(data.plants);
          final hasResults = filteredCategories.isNotEmpty || filteredPlants.isNotEmpty;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: _SearchBar(
                    key: _searchBarKey,
                    onSearchChanged: _updateSearchQuery,
                    onSearch: _performSearch,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty && !hasResults)
                SliverToBoxAdapter(
                  child: _NoResultsFound(searchQuery: _searchQuery),
                )
              else ...[
                if (filteredCategories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _CategorySection(categories: filteredCategories),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  sliver: _PlantGrid(plants: filteredPlants),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // Beautiful loading animation to keep users engaged
  Widget _buildBeautifulLoadingAnimation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated plant growing - continuously pulsing
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final value = _animationController.value;
                // Create a pulsing effect: scale goes 0.85 -> 1.0 -> 0.85
                final pulseValue = 0.85 + (0.15 * (1 - (value - 0.5).abs() * 2));
                
                return Transform.scale(
                  scale: pulseValue,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing circle
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                        ),
                      ),
                      // Middle circle
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                        ),
                      ),
                      // Inner gradient circle with icon - rotating
                      Transform.rotate(
                        angle: value * 2 * 3.14159, // Full rotation
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Transform.rotate(
                            angle: -value * 2 * 3.14159, // Counter-rotate icon to keep it upright
                            child: const Icon(
                              Icons.local_florist,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Loading text
            Text(
              'Discovering plants',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              'Searching for plants…',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Animated dots - continuously pulsing
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    // Stagger the animation for each dot
                    final offset = index * 0.33; // 0, 0.33, 0.66
                    final dotValue = (_animationController.value + offset) % 1.0;
                    // Create bounce effect: 0 -> 1 -> 0
                    final bounceValue = (1 - (dotValue - 0.5).abs() * 2);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 8 + (bounceValue * 4), // Size varies 8-12px
                        height: 8 + (bounceValue * 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            Colors.grey[300],
                            const Color(0xFF4CAF50),
                            bounceValue,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _SearchBar extends StatefulWidget {
  const _SearchBar({
    super.key,
    required this.onSearchChanged,
    required this.onSearch,
  });

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearch;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clearSearch() {
    _controller.clear();
    widget.onSearchChanged('');
    setState(() {});
  }

  void _handleSearchChange(String value) {
    widget.onSearchChanged(value);
  }
  
  void _handleSearchSubmit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSearch(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Search any plant, tree, or flower…',
              hintMaxLines: 2,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              // prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4CAF50)),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                        setState(() {});
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF4CAF50)),
                      onPressed: () {
                        if (_controller.text.trim().isNotEmpty) {
                          _handleSearchSubmit();
                        }
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {});
              _handleSearchChange(value);
            },
            onSubmitted: (value) {
              _handleSearchSubmit();
            },
            textInputAction: TextInputAction.search,
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categories});

  final List<PlantCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlantDetailSearchScreen(
                    plantName: category.name,
                    scientificName: category.description,
                    category: category.name,
                    thumbnailUrl: category.thumbnail,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: category.thumbnail.isEmpty
                        ? Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 32),
                          )
                        : Image.network(
                            category.thumbnail,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFFE8F5E9),
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
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE8F5E9),
                              child: const Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 32),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 90,
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlantGrid extends StatelessWidget {
  const _PlantGrid({required this.plants});

  final List<PlantSummary> plants;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (plants.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  const Icon(Icons.local_florist_outlined, size: 48, color: Color(0xFF4CAF50)),
                  const SizedBox(height: 12),
                  Text(
                    'No plant suggestions yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull to refresh or try again later.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final plant = plants[index];
              return _PlantCard(plant: plant);
            },
            childCount: plants.length,
          ),
        );
      },
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant});

  final PlantSummary plant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlantDetailSearchScreen(
                  plantName: plant.displayName,
                  scientificName: plant.scientificName,
                  category: plant.category,
                  thumbnailUrl: plant.thumbnail,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: plant.thumbnail.isEmpty
                  ? Container(
                      color: const Color(0xFFE8F5E9),
                      child: const Center(
                        child: Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 48),
                      ),
                    )
                  : Image.network(
                      plant.thumbnail,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFE8F5E9),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: Icon(Icons.local_florist, color: Color(0xFF4CAF50), size: 48),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  plant.scientificName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    plant.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
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
      ],
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.onSearch,
  });

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            // Animated icon container
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Find a Plant Instantly',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'Just search, we’ll help you find it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            // Search suggestions
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _SearchSuggestionChip(
                  icon: Icons.eco,
                  text: 'Tulips',
                  onTap: () => onSearch('Tulips'),
                ),
                _SearchSuggestionChip(
                  icon: Icons.local_florist,
                  text: 'Rose',
                  onTap: () => onSearch('Rose'),
                ),
                _SearchSuggestionChip(
                  icon: Icons.park,
                  text: 'Peace lily',
                  onTap: () => onSearch('Peace lily'),
                ),

                _SearchSuggestionChip(
                  icon: Icons.forest,
                  text: 'Monstera',
                  onTap: () => onSearch('Monstera'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestionChip extends StatelessWidget {
  const _SearchSuggestionChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBottomHint extends StatelessWidget {
  const _SearchBottomHint();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tips_and_updates, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Suggestions are personalized for your location and cached. Pull down to refresh when you travel.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResultsFound extends StatelessWidget {
  const _NoResultsFound({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Results Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No plants found matching "$searchQuery"',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching with different keywords',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFF57C00)),
            const SizedBox(height: 12),
            Text(
              'Unable to load suggestions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontSize: 15,
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

class _SearchModeIndicator extends StatelessWidget {
  const _SearchModeIndicator({required this.isGlobal});

  final bool isGlobal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isGlobal 
            ? const Color(0xFF4CAF50).withOpacity(0.1)
            : const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGlobal 
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0xFF2196F3).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGlobal 
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : const Color(0xFF2196F3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isGlobal ? Icons.public_rounded : Icons.location_on_rounded,
              color: isGlobal ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGlobal ? 'Global Search' : 'Local Search',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isGlobal ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isGlobal 
                      ? 'AI-powered search across all plant knowledge'
                      : 'Searching plants in your local area',
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

class _GlobalSearchSection extends StatelessWidget {
  const _GlobalSearchSection({
    required this.query,
    required this.response,
    required this.onClear,
  });

  final String query;
  final String response;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.public_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Global Search Results',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    query,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: onClear,
              tooltip: 'Clear results',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Result Card with clean text content
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              response,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GlobalSearchEmptyState extends StatelessWidget {
  const _GlobalSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF2E7D32),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Can't spot your plant here?\n\nUse Identify Plant to scan it instantly",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
