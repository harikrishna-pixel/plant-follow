import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../model/data_model/folder_model.dart';
import '../../../model/data_model/plant_model.dart';
import '../../../provider/folder_provider.dart';
import '../../../provider/plant_provider.dart';
import 'favourite_details.dart';

class FolderDetailScreen extends StatelessWidget {
  final PlantFolder folder;
  const FolderDetailScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      body: Consumer2<FolderProvider, PlantProvider>(
        builder: (context, folderProvider, plantProvider, child) {
          // Get the updated folder from provider
          final currentFolder = folderProvider.getFolderById(folder.id);
          
          if (currentFolder == null) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Garden Not Found', style: GoogleFonts.poppins()),
                backgroundColor: Colors.white,
              ),
              body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Garden not found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            );
          }

          // Get all favorite plants
          final allPlants = plantProvider.favorites;
          
          print('🔍 Folder Detail Screen Debug:');
          print('  Folder: ${currentFolder.name}');
          print('  Folder IDs stored: ${currentFolder.plantIds}');
          print('  Total favorites: ${allPlants.length}');
          
          // Filter plants that are in this folder
          final plantsInFolder = allPlants.where((plant) {
            final plantId = plant.uniqueId;
            print('  Checking plant: ${plant.name} (ID: $plantId)');
            final isMatch = currentFolder.plantIds.contains(plantId);
            print('    Match: $isMatch');
            return isMatch;
          }).toList();
          
          print('  Plants found in folder: ${plantsInFolder.length}');
          
          // NOTE: Automatic orphaned ID cleanup is disabled to prevent accidental deletion
          // of valid plants. Plants will remain in folders even if there are temporary
          // ID mismatches. Users can manually remove plants if needed.
          // 
          // If you need to clean up truly orphaned IDs, do it manually or on explicit user action
          // 
          // Disabled automatic cleanup:
          // if (plantsInFolder.length < currentFolder.plantIds.length) {
          //   print('  🧹 Found orphaned IDs - will clean after build...');
          //   final validIds = plantsInFolder.map((p) => p.uniqueId).toList();
          //   final orphanedIds = currentFolder.plantIds.where((id) => !validIds.contains(id)).toList();
          //   print('  Orphaned IDs: $orphanedIds');
          //   
          //   // Schedule cleanup AFTER the build phase
          //   WidgetsBinding.instance.addPostFrameCallback((_) {
          //     for (var orphanedId in orphanedIds) {
          //       folderProvider.removePlantFromFolder(currentFolder.id, orphanedId);
          //     }
          //   });
          // }

          // Build AppBar with actual plant count
          final appBar = AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentFolder.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '${plantsInFolder.length} plants',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFF44336)),
                onPressed: () {
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          );

          if (currentFolder.plantIds.isEmpty || plantsInFolder.isEmpty) {
            return Scaffold(
              appBar: appBar,
              body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Plants not found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Some plants may have been deleted',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            );
          }

          return Scaffold(
            appBar: appBar,
            body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: plantsInFolder.length,
            itemBuilder: (context, index) {
              final plant = plantsInFolder[index];
              return _buildPlantCard(context, plant, folderProvider, currentFolder);
            },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlantCard(BuildContext context, Plant plant, FolderProvider folderProvider, PlantFolder currentFolder) {
    final plantId = plant.uniqueId;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FavoriteDetailScreen(plant: plant),
          ),
        );
      },
      child: Container(
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
            // Plant Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: (plant.imageFile != null &&
                            File(plant.imageFile!.path).existsSync())
                        ? Image.file(
                            plant.imageFile!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: const Color(0xFFE8F5E8),
                            child: const Icon(
                              Icons.local_florist,
                              size: 50,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                  ),
                  // Remove from folder button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        print('🗑️ Removing plant from folder:');
                        print('  Folder: ${currentFolder.name}');
                        print('  Plant: ${plant.name}');
                        print('  Plant ID: $plantId');
                        
                        folderProvider.removePlantFromFolder(currentFolder.id, plantId);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Removed from ${currentFolder.name}',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFFF44336),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFFF44336),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Plant Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name.isNotEmpty ? plant.name : 'Unknown Plant',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plant.scientificName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      plant.scientificName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Garden?',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF44336),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${folder.name}"?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = Provider.of<FolderProvider>(context, listen: false);
              provider.deleteFolder(folder.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to folder list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Garden deleted', style: GoogleFonts.poppins()),
                  backgroundColor: const Color(0xFFF44336),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
