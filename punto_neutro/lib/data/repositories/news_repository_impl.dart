import '../../domain/repositories/news_repository.dart';
import '../../domain/models/news_item.dart';
import '../../domain/models/rating_item.dart';
import '../../domain/models/comment.dart';

class NewsRepositoryImpl implements NewsRepository {
  @override
  Future<List<NewsItem>> getNewsList() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _staticNewsItems;
  }
  final List<NewsItem> _staticNewsItems = [
    NewsItem(
      news_item_id: '1',
      user_profile_id: 'user_1',
      title: 'Advances in automatic verification technology combat fake news',
      short_description: 'New AI algorithms can identify manipulated content with 98% accuracy.',
      image_url: 'assets/images/image1.jpeg',
      category_id: 'Technology',
      author_type: 'Verified author',
      author_institution: 'Tech Research Institute',
      days_since: 5,
      comments_count: 23,
      average_reliability_score: 0.68,
      is_fake: false,
      is_verified_source: true,
      is_verified_data: true,
      is_recognized_author: true,
      is_manipulated: false,
      long_description: 'Researchers have developed advanced artificial intelligence systems capable of detecting manipulated content, deepfakes and fake news with unprecedented 98% accuracy.\n\nThis advancement represents a significant milestone in the fight against digital misinformation, which has become one of the greatest challenges of our digital era.',
      original_source_url: 'https://example.com/original-article',
      publication_date: DateTime(2025, 1, 15, 5, 30),
      added_to_app_date: DateTime(2025, 1, 16, 10, 0),
      total_ratings: 156,
    ),
  ];

  final List<Comment> _staticComments = [
    Comment(
      comment_id: '1',
      news_item_id: '1',
      user_profile_id: 'user_2',
      user_name: 'Anonymous user',
      content: 'Excellent article. It\'s reassuring to know that tools exist to combat misinformation. The research seems very solid and well-documented.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Comment(
      comment_id: '2',
      news_item_id: '1',
      user_profile_id: 'user_3',
      user_name: 'Anonymous user',
      content: 'When will this technology be available to the general public? The information seems credible but needs more details about implementation.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<NewsItem> getNewsDetail(String news_item_id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _staticNewsItems.firstWhere((item) => item.news_item_id == news_item_id);
  }

  @override
  Future<List<Comment>> getComments(String news_item_id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _staticComments.where((comment) => comment.news_item_id == news_item_id).toList();
  }

  @override
  Future<void> submitRating(RatingItem rating_item) async {
    await Future.delayed(const Duration(milliseconds: 800));
    print('RatingItem enviado: ${rating_item.toJson()}');
  }

  @override
  Future<void> submitComment(Comment comment) async {
    await Future.delayed(const Duration(milliseconds: 800));
    print('Comment enviado: ${comment.toJson()}');
  }

  @override
  Future<NewsItem> createNewsArticle({
    required String title,
    required String shortDescription,
    required String longDescription,
    required String categoryId,
    required String authorId,
    required String authorType,
    required String authorInstitution,
    String? imageUrl,
    String? originalSourceUrl,
    bool isDraft = false,
  }) async {
    // Mock implementation - just delay and return a fake news item
    await Future.delayed(const Duration(milliseconds: 800));
    
    return NewsItem(
      news_item_id: DateTime.now().millisecondsSinceEpoch.toString(),
      user_profile_id: authorId,
      title: title,
      short_description: shortDescription,
      long_description: longDescription,
      image_url: imageUrl ?? '',
      category_id: categoryId,
      author_type: authorType,
      author_institution: authorInstitution,
      days_since: 0,
      comments_count: 0,
      average_reliability_score: 0.0,
      is_fake: false,
      is_verified_source: false,
      is_verified_data: false,
      is_recognized_author: false,
      is_manipulated: false,
      original_source_url: originalSourceUrl ?? '',
      publication_date: DateTime.now(),
      added_to_app_date: DateTime.now(),
      total_ratings: 0,
    );
  }
  
  @override
  Future<int> getRatingsCount(String news_item_id) {
    // TODO: implement getRatingsCount
    throw UnimplementedError();
  }
}