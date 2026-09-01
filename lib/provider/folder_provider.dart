import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_model/folder_model.dart';
import '../model/data_model/plant_model.dart';

class FolderProvider extends ChangeNotifier {
  List<PlantFolder> _folders = [];
  static const String _folderKey = 'plant_folders';

  List<PlantFolder> get folders => _folders;

  FolderProvider() {
    loadFolders();
  }

  Future<void> loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = prefs.getString(_folderKey);
      
      if (foldersJson != null) {
        final List<dynamic> decoded = jsonDecode(foldersJson);
        _folders = decoded.map((json) => PlantFolder.fromJson(json)).toList();
        
        print('📂 Loaded folders from storage:');
        print('  Total folders: ${_folders.length}');
        
        // Check for duplicates
        final seenIds = <String>{};
        final duplicates = <String>[];
        for (var folder in _folders) {
          if (seenIds.contains(folder.id)) {
            duplicates.add(folder.id);
            print('  ⚠️ DUPLICATE: ${folder.name} (ID: ${folder.id})');
          } else {
            seenIds.add(folder.id);
            print('  - ${folder.name} (ID: ${folder.id}, Plants: ${folder.plantIds.length})');
          }
        }
        
        // Remove duplicates if found
        if (duplicates.isNotEmpty) {
          print('  🔧 Removing ${duplicates.length} duplicate(s)...');
          final uniqueFolders = <String, PlantFolder>{};
          for (var folder in _folders) {
            uniqueFolders[folder.id] = folder;
          }
          _folders = uniqueFolders.values.toList();
          print('  After deduplication: ${_folders.length} folders');
          _saveFolders();
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = jsonEncode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_folderKey, foldersJson);
    } catch (e) {
      print('Error saving folders: $e');
    }
  }

  void createFolder(String name, String? description) {
    final folder = PlantFolder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    
    print('➕ Creating new folder:');
    print('  Name: $name');
    print('  ID: ${folder.id}');
    print('  Current total folders: ${_folders.length}');
    
    _folders.add(folder);
    
    print('  After add: ${_folders.length} folders');
    
    _saveFolders();
    notifyListeners();
  }

  void deleteFolder(String folderId) {
    _folders.removeWhere((folder) => folder.id == folderId);
    _saveFolders();
    notifyListeners();
  }

  void addPlantToFolder(String folderId, String plantId) {
    print('🔍 Adding plant to folder:');
    print('  Folder ID: $folderId');
    print('  Plant ID: $plantId');
    
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    print('  Folder Index: $folderIndex');
    
    if (folderIndex != -1) {
      if (!_folders[folderIndex].plantIds.contains(plantId)) {
        _folders[folderIndex].plantIds.add(plantId);
        print('  ✅ Added! Total plants in folder: ${_folders[folderIndex].plantIds.length}');
        print('  Plant IDs: ${_folders[folderIndex].plantIds}');
        _saveFolders();
        notifyListeners();
      } else {
        print('  ⚠️ Plant already in folder');
      }
    } else {
      print('  ❌ Folder not found!');
    }
  }

  void addPlantRecordToFolder(String folderId, Plant plant) {
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;
    if (_folders[folderIndex].containsPlant(plant)) return;
    addPlantToFolder(folderId, plant.id);
  }

  void removePlantFromFolder(String folderId, String plantId) {
    print('🗑️ Removing plant from folder (Provider):');
    print('  Folder ID: $folderId');
    print('  Plant ID: $plantId');
    
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    print('  Folder Index: $folderIndex');
    
    if (folderIndex != -1) {
      print('  Before removal: ${_folders[folderIndex].plantIds.length} plants');
      print('  Plant IDs: ${_folders[folderIndex].plantIds}');
      
      final removed = _folders[folderIndex].plantIds.remove(plantId);
      
      if (removed) {
        print('  ✅ Removed! After removal: ${_folders[folderIndex].plantIds.length} plants');
        print('  Remaining IDs: ${_folders[folderIndex].plantIds}');
        _saveFolders();
        notifyListeners();
      } else {
        print('  ⚠️ Plant ID not found in folder!');
      }
    } else {
      print('  ❌ Folder not found!');
    }
  }

  void removePlantRecordFromFolder(String folderId, Plant plant) {
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;
    final before = _folders[folderIndex].plantIds.length;
    _folders[folderIndex].plantIds.removeWhere(plant.matchesStoredId);
    if (_folders[folderIndex].plantIds.length != before) {
      _saveFolders();
      notifyListeners();
    }
  }

  void updateFolder(String folderId, String name, String? description) {
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    if (folderIndex != -1) {
      _folders[folderIndex] = _folders[folderIndex].copyWith(
        name: name,
        description: description,
      );
      _saveFolders();
      notifyListeners();
    }
  }

  List<String> getFolderIdsForPlant(String plantId) {
    return _folders
        .where((folder) => folder.plantIds.contains(plantId))
        .map((folder) => folder.id)
        .toList();
  }

  List<String> getFolderIdsForPlantRecord(Plant plant) {
    return _folders
        .where((folder) => folder.containsPlant(plant))
        .map((folder) => folder.id)
        .toList();
  }

  PlantFolder? getFolderById(String folderId) {
    try {
      return _folders.firstWhere((folder) => folder.id == folderId);
    } catch (e) {
      return null;
    }
  }
}
