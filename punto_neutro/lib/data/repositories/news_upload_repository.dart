import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/news_draft.dart';

/// News Upload Repository
///
/// Handles uploading user-created news articles with images to Supabase backend.
/// Uses multipart form-data for articles + multiple images.
///
/// Features:
/// - Multipart upload (JSON + images in single request)
/// - Idempotency key (UUID) for safe retries
/// - Supabase Storage for images
/// - RLS enforcement (user can only create their own news)
/// - Progress tracking (optional callback)
///
/// Backend Requirements:
/// - POST /rest/v1/news_items endpoint
/// - Supabase Storage bucket: 'news-images' (public read)
/// - RLS policy: authenticated users can INSERT own news_items
///
/// Upload Flow:
/// 1. Upload images to Supabase Storage (parallel)
/// 2. Create news_item record with image URLs
/// 3. Return created news_item_id
/// 4. Handle idempotency (duplicate key = return existing)

class NewsUploadRepository {
  final SupabaseClient _client;
  final String _storageBucket;

  NewsUploadRepository({
    SupabaseClient? client,
    String storageBucket = 'news-images',
  })  : _client = client ?? Supabase.instance.client,
        _storageBucket = storageBucket;

  /// Upload news article with images
  ///
  /// Returns created news_item_id on success.
  /// Throws exception on failure.
  ///
  /// [draft] - News draft with processed images
  /// [idempotencyKey] - UUID for deduplication (from upload queue)
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  Future<String> uploadNews(
    NewsDraft draft, {
    required String idempotencyKey,
    void Function(double progress)? onProgress,
  }) async {
    if (!draft.isReadyToUpload) {
      throw Exception(
          'Draft not ready to upload. Check validation: ${draft.uploadError}');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated. Cannot upload news.');
    }

    try {
      // Step 1: Upload images to Supabase Storage (parallel)
      onProgress?.call(0.1); // 10% - starting image upload
      final imageUrls = await _uploadImages(
        draft.images,
        userId: userId,
        onProgress: (imageProgress) {
          // Images take 60% of total progress (0.1 to 0.7)
          onProgress?.call(0.1 + (imageProgress * 0.6));
        },
      );

      onProgress?.call(0.7); // 70% - images uploaded

      // Step 2: Create news_item record with image URLs
      final newsItemData = {
        'title': draft.title,
        'content': draft.content,
        'category_id': draft.categoryId,
        'source_url': draft.sourceUrl,
        'user_profile_id': userId,
        'image_urls': imageUrls, // Array of image URLs
        'idempotency_key': idempotencyKey,
        'published_at': DateTime.now().toIso8601String(),
      };

      onProgress?.call(0.8); // 80% - creating record

      final response = await _client
          .from('news_items')
          .insert(newsItemData)
          .select('news_item_id')
          .single();

      onProgress?.call(1.0); // 100% - complete

      final newsItemId = response['news_item_id'] as String;
      return newsItemId;
    } on PostgrestException catch (e) {
      // Handle duplicate idempotency key (safe retry)
      if (e.code == '23505' && e.message.contains('idempotency_key')) {
        // Duplicate key - fetch existing news_item_id
        final existing = await _client
            .from('news_items')
            .select('news_item_id')
            .eq('idempotency_key', idempotencyKey)
            .single();

        return existing['news_item_id'] as String;
      }

      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Upload images to Supabase Storage (parallel)
  ///
  /// Returns list of public URLs for uploaded images.
  Future<List<String>> _uploadImages(
    List<DraftImage> images, {
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    if (images.isEmpty) {
      return [];
    }

    final uploadFutures = <Future<String>>[];
    int completed = 0;

    for (final draftImage in images) {
      // Use compressed image if available, otherwise original
      final imagePath = draftImage.compressedPath ?? draftImage.localPath;
      final file = File(imagePath);

      if (!file.existsSync()) {
        throw Exception('Image file not found: $imagePath');
      }

      // Generate unique filename: {userId}/{timestamp}_{random}.jpg
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '$userId/${timestamp}_${file.uri.pathSegments.last}';

      // Upload to Supabase Storage
      final uploadFuture = _client.storage
          .from(_storageBucket)
          .upload(filename, file)
          .then((uploadPath) {
        completed++;
        onProgress?.call(completed / images.length);

        // Return public URL
        return _client.storage.from(_storageBucket).getPublicUrl(filename);
      });

      uploadFutures.add(uploadFuture);
    }

    // Wait for all uploads to complete (parallel)
    final imageUrls = await Future.wait(uploadFutures);
    return imageUrls;
  }

  /// Check if backend is available (health check)
  Future<bool> isAvailable() async {
    try {
      // Simple query to test connectivity
      await _client
          .from('news_items')
          .select('news_item_id')
          .limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Backend SQL for idempotency support:
///
/// ALTER TABLE public.news_items
/// ADD COLUMN IF NOT EXISTS idempotency_key UUID UNIQUE;
///
/// CREATE UNIQUE INDEX IF NOT EXISTS idx_news_items_idempotency
/// ON public.news_items(idempotency_key)
/// WHERE idempotency_key IS NOT NULL;
///
/// COMMENT ON COLUMN public.news_items.idempotency_key IS
/// 'Unique key for preventing duplicate uploads on retry (client-generated UUID)';
///
/// -- RLS Policy: Users can insert their own news
/// CREATE POLICY "Users can create own news"
/// ON public.news_items
/// FOR INSERT
/// TO authenticated
/// WITH CHECK (auth.uid() = user_profile_id);
///
/// -- Storage bucket permissions
/// -- Bucket: news-images (public read, authenticated write)
/// -- INSERT INTO storage.buckets (id, name, public)
/// -- VALUES ('news-images', 'news-images', true);
///
/// -- Storage policy: Users can upload to their folder
/// CREATE POLICY "Users can upload own images"
/// ON storage.objects
/// FOR INSERT
/// TO authenticated
/// WITH CHECK (bucket_id = 'news-images' AND (storage.foldername(name))[1] = auth.uid()::text);
///
/// -- Storage policy: Anyone can read images
/// CREATE POLICY "Public read images"
/// ON storage.objects
/// FOR SELECT
/// TO public
/// USING (bucket_id = 'news-images');

/// Example usage:
///
/// ```dart
/// final repository = NewsUploadRepository();
/// final draft = NewsDraft(...); // Prepared draft
/// final idempotencyKey = const Uuid().v4(); // Generate UUID
///
/// try {
///   final newsItemId = await repository.uploadNews(
///     draft,
///     idempotencyKey: idempotencyKey,
///     onProgress: (progress) {
///       print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
///     },
///   );
///   
///   print('News uploaded successfully: $newsItemId');
/// } catch (e) {
///   print('Upload failed: $e');
/// }
/// ```
