import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Utility class for image compression
/// Does NOT create widgets - only pure image processing
class ImageCompression {
  ImageCompression._();

  /// Compress image to reduce file size for upload
  /// Max dimension: 1920px, Quality: 85%
  /// Returns compressed File
  static Future<File> compressImage(File imageFile) async {
    // Read image bytes
    final Uint8List imageBytes = await imageFile.readAsBytes();

    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      // If decoding fails, return original
      return imageFile;
    }

    // Resize if too large (maintain aspect ratio)
    const int maxDimension = 1920;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: maxDimension);
      } else {
        image = img.copyResize(image, height: maxDimension);
      }
    }

    // Compress as JPEG with 85% quality
    final List<int> compressedBytes = img.encodeJpg(image, quality: 85);

    // Save to temporary file
    final String fileName = imageFile.path.split('/').last;
    final Directory tempDir = await getTemporaryDirectory();
    final File compressedFile = File('${tempDir.path}/compressed_$fileName')
      ..writeAsBytesSync(compressedBytes);

    return compressedFile;
  }

  /// Compress multiple images in parallel
  /// Returns list of compressed Files
  static Future<List<File>> compressImages(List<File> imageFiles) async {
    // Use Future.wait for parallel processing (faster)
    return await Future.wait(
      imageFiles.map((file) => compressImage(file)),
    );
  }
}
