import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a gallery/camera pick into app storage before the iOS PHPicker
/// temp file disappears. Identify/Diagnose read the file after network checks;
/// Chat does not, which is why gallery looked fine there.
class PickedMedia {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickPlantPhoto({
    required ImageSource source,
    int imageQuality = 85,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      // Avoid a full Photo Library permission request on iOS 14+ PHPicker.
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return persist(picked);
  }

  static Future<XFile> persist(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Selected image was empty');
    }
    final dir = await getTemporaryDirectory();
    final dest = File(
      '${dir.path}/plant_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await dest.writeAsBytes(bytes, flush: true);
    if (!dest.existsSync() || dest.lengthSync() == 0) {
      throw StateError('Could not save the selected image');
    }
    debugPrint('PickedMedia saved ${dest.path} (${bytes.length} bytes)');
    return XFile(dest.path);
  }
}
