import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/news_draft.dart';

/// Service for processing images in background using Isolates.
/// 
/// This service:
/// - Compresses images to reduce upload size
/// - Generates thumbnails for previews
/// - Runs off the main thread (UI remains responsive)
/// - Processes multiple images in parallel
/// 
/// Usage:
/// ```dart
/// final service = ImageProcessingService();
/// final result = await service.processImage('/path/to/image.jpg');
/// // result contains compressed and thumbnail paths
/// ```
class ImageProcessingService {
  /// Process a single image (compress + thumbnail)
  /// This runs in an Isolate to avoid blocking the UI
  Future<ProcessedImage> processImage(String imagePath) async {
    try {
      print('ImageProcessingService: Processing $imagePath');

      // Get original file size
      final originalFile = File(imagePath);
      final originalSize = await originalFile.length();

      // Create message for isolate
      final message = _ImageProcessingMessage(
        imagePath: imagePath,
        targetQuality: 85, // 85% quality for good balance
        thumbnailSize: 200, // 200px thumbnail
      );

      // Spawn isolate and process image
      final result = await _processInIsolate(message);

      print(
          'ImageProcessingService: Completed. Compressed: ${result.compressedPath}');

      return ProcessedImage(
        originalPath: imagePath,
        compressedPath: result.compressedPath,
        thumbnailPath: result.thumbnailPath,
        originalSizeBytes: originalSize,
        compressedSizeBytes: result.compressedSize,
      );
    } catch (e) {
      print('ImageProcessingService: Error processing image: $e');
      rethrow;
    }
  }

  /// Process multiple images in parallel
  Future<List<ProcessedImage>> processImages(List<String> imagePaths) async {
    final futures = imagePaths.map((path) => processImage(path));
    return await Future.wait(futures);
  }

  /// Spawn an isolate to process the image
  Future<_ImageProcessingResult> _processInIsolate(
      _ImageProcessingMessage message) async {
    final receivePort = ReceivePort();

    // Spawn isolate
    await Isolate.spawn(
      _imageProcessingIsolate,
      _IsolateParams(
        sendPort: receivePort.sendPort,
        message: message,
      ),
    );

    // Wait for result
    final result = await receivePort.first as _ImageProcessingResult;
    return result;
  }
}

/// Top-level function that runs in the isolate
/// This is where the heavy image processing happens
@pragma('vm:entry-point')
void _imageProcessingIsolate(_IsolateParams params) async {
  try {
    final message = params.message;
    final sendPort = params.sendPort;

    // Get app directory for saving processed images
    final appDir = await getApplicationDocumentsDirectory();
    final processedDir = Directory(path.join(appDir.path, 'processed_images'));
    if (!await processedDir.exists()) {
      await processedDir.create(recursive: true);
    }

    final filename = path.basenameWithoutExtension(message.imagePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Compress image
    final compressedPath =
        path.join(processedDir.path, '${filename}_compressed_$timestamp.jpg');

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      message.imagePath,
      compressedPath,
      quality: message.targetQuality,
      format: CompressFormat.jpeg,
    );

    if (compressedFile == null) {
      throw Exception('Failed to compress image');
    }

    final compressedSize = await File(compressedPath).length();

    // Generate thumbnail
    final thumbnailPath =
        path.join(processedDir.path, '${filename}_thumb_$timestamp.jpg');

    await FlutterImageCompress.compressAndGetFile(
      message.imagePath,
      thumbnailPath,
      quality: 80,
      minWidth: message.thumbnailSize,
      minHeight: message.thumbnailSize,
      format: CompressFormat.jpeg,
    );

    // Send result back to main isolate
    sendPort.send(_ImageProcessingResult(
      compressedPath: compressedPath,
      thumbnailPath: thumbnailPath,
      compressedSize: compressedSize,
    ));
  } catch (e) {
    print('Image processing isolate error: $e');
    params.sendPort.send(_ImageProcessingResult(
      compressedPath: '',
      thumbnailPath: '',
      compressedSize: 0,
      error: e.toString(),
    ));
  }
}

/// Parameters passed to the isolate
class _IsolateParams {
  final SendPort sendPort;
  final _ImageProcessingMessage message;

  _IsolateParams({
    required this.sendPort,
    required this.message,
  });
}

/// Message sent to isolate with processing parameters
class _ImageProcessingMessage {
  final String imagePath;
  final int targetQuality; // 0-100
  final int thumbnailSize; // pixels

  _ImageProcessingMessage({
    required this.imagePath,
    required this.targetQuality,
    required this.thumbnailSize,
  });
}

/// Result returned from isolate after processing
class _ImageProcessingResult {
  final String compressedPath;
  final String thumbnailPath;
  final int compressedSize;
  final String? error;

  _ImageProcessingResult({
    required this.compressedPath,
    required this.thumbnailPath,
    required this.compressedSize,
    this.error,
  });
}

/// Result of image processing operation
class ProcessedImage {
  final String originalPath;
  final String compressedPath;
  final String thumbnailPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;

  ProcessedImage({
    required this.originalPath,
    required this.compressedPath,
    required this.thumbnailPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
  });

  /// Calculate compression ratio (0-100%)
  int get compressionRatio {
    return ((1 - (compressedSizeBytes / originalSizeBytes)) * 100).round();
  }

  /// Convert to DraftImage for use in NewsDraft
  DraftImage toDraftImage() {
    return DraftImage(
      localPath: originalPath,
      compressedPath: compressedPath,
      thumbnailPath: thumbnailPath,
      processingStatus: ImageProcessingStatus.completed,
      originalSizeBytes: originalSizeBytes,
      compressedSizeBytes: compressedSizeBytes,
    );
  }
}
