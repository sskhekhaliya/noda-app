import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Generic utilities for image management in Noda.
class ImageUtils {
  ImageUtils._();

  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery and saves it to the local app documents directory.
  /// Returns the permanent local file path of the saved image.
  static Future<String?> pickAndSaveImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Subtle compression to save space
      );

      if (pickedFile == null) return null;

      // Get permanent storage directory
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String mediaDirPath = p.join(docDir.path, 'media');
      final Directory mediaDir = Directory(mediaDirPath);

      // Ensure directory exists
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      // Generate a unique filename to avoid collisions
      final String extension = p.extension(pickedFile.path);
      final String fileName = 'noda_img_${const Uuid().v4()}$extension';
      final String permanentPath = p.join(mediaDirPath, fileName);

      // Copy the file to local storage
      await File(pickedFile.path).copy(permanentPath);

      return permanentPath;
    } catch (e) {
      // In a real app, we might want to log this or throw a custom exception
      return null;
    }
  }
}

