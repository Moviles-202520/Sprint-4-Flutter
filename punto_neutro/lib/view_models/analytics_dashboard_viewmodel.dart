import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ NUEVO ANALYTICS DASHBOARD CON LAS 5 BUSINESS QUESTIONS REQUERIDAS
/// Implementa las BQ específicas solicitadas para el dashboard
class AnalyticsDashboardViewModel extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Streams para datos en tiempo real
  StreamSubscription<List<Map<String, dynamic>>>? _ratingsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _engagementStream;

  // ✅ BQ1: Personal bias score vs community averages
  Map<String, dynamic> _personalBiasData = {};
  
  // ✅ BQ2: Veracity ratings by source
  List<Map<String, dynamic>> _sourceVeracityData = [];
  
  // ✅ BQ3: Conversion rate from shared articles
  Map<String, dynamic> _conversionRateData = {};
  
  // ✅ BQ4: Rating distribution by category
  List<Map<String, dynamic>> _categoryDistributionData = [];
  
  // ✅ BQ5: Engagement vs accuracy correlation
  Map<String, dynamic> _engagementAccuracyData = {};

  bool _isLoading = false;
  String? _error;

  // Getters para la UI
  Map<String, dynamic> get personalBiasData => _personalBiasData;
  List<Map<String, dynamic>> get sourceVeracityData => _sourceVeracityData;
  Map<String, dynamic> get conversionRateData => _conversionRateData;
  List<Map<String, dynamic>> get categoryDistributionData => _categoryDistributionData;
  Map<String, dynamic> get engagementAccuracyData => _engagementAccuracyData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// ✅ INICIALIZAR DASHBOARD CON TODAS LAS BQ
  Future<void> initializeDashboard({int? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadBQ1PersonalBiasScore(userId),
        _loadBQ2SourceVeracityAnalysis(),
        _loadBQ3ConversionRateAnalysis(),
        _loadBQ4CategoryDistribution(),
        _loadBQ5EngagementAccuracyCorrelation(),
        // ⚠️ NUEVAS BQ (Milestone H)
        loadBQH1DarkModeUsage(),
        loadBQH2NewsCreation(),
        loadBQH3Personalization(),
        loadBQH4UserActions(),
        loadBQH5SourceSatisfaction(),
      ]);

      // Iniciar streams en tiempo real
      _startRealTimeUpdates();
      
    } catch (e) {
      _error = 'Error cargando dashboard: $e';
      print('❌ Error en dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ BQ1: Personal bias score vs community averages
  Future<void> _loadBQ1PersonalBiasScore(int? userId) async {
    try {
      // Obtener user_profile_id desde user_profiles usando auth id
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        _personalBiasData = {'error': 'Usuario no autenticado'};
        return;
      }

      // Buscar user_profile_id
      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_profile_id')
          .eq('user_auth_id', authUserId)
          .maybeSingle();

      if (userProfile == null) {
        _personalBiasData = {'error': 'Perfil de usuario no encontrado'};
        return;
      }

      final userProfileId = userProfile['user_profile_id'] as int;

      // Obtener ratings del usuario
      final userRatings = await _supabase
          .from('rating_items')
          .select('assigned_reliability_score, news_item_id')
          .eq('user_profile_id', userProfileId);

      // Obtener promedios de la comunidad
      final communityAvgs = await _supabase
          .from('rating_items')
          .select('assigned_reliability_score')
          .neq('user_profile_id', userProfileId);

      if (userRatings.isEmpty) {
        _personalBiasData = {
          'user_ratings_count': 0,
          'message': 'Necesitas más ratings para ver tu análisis'
        };
        return;
      }

      // Calcular promedios del usuario (solo reliability, bias no existe en Supabase)
      final userAvgReliability = userRatings
          .where((r) => r['assigned_reliability_score'] != null)
          .map((r) => (r['assigned_reliability_score'] as num).toDouble())
          .fold(0.0, (a, b) => a + b) / userRatings.where((r) => r['assigned_reliability_score'] != null).length;

      // Calcular promedios de la comunidad
      final validCommunityRatings = communityAvgs.where((r) => r['assigned_reliability_score'] != null).toList();
      final communityAvgReliability = validCommunityRatings.isNotEmpty
          ? validCommunityRatings
              .map((r) => (r['assigned_reliability_score'] as num).toDouble())
              .reduce((a, b) => a + b) / validCommunityRatings.length
          : 0.0;

      _personalBiasData = {
        'user_profile_id': userProfileId,
        'user_ratings_count': userRatings.length,
        'user_avg_reliability': userAvgReliability,
        'user_avg_bias': userAvgReliability, // Usar reliability como proxy (bias no existe)
        'community_avg_reliability': communityAvgReliability,
        'community_avg_bias': communityAvgReliability, // Usar reliability como proxy
        'reliability_difference': userAvgReliability - communityAvgReliability,
        'bias_difference': 0.0, // No disponible en Supabase
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ1 Personal Bias Score cargado (${userRatings.length} ratings)');
    } catch (e) {
      print('❌ Error en BQ1: $e');
      _personalBiasData = {'error': e.toString()};
    }
  }

  /// ✅ BQ2: Source veracity analysis
  Future<void> _loadBQ2SourceVeracityAnalysis() async {
    try {
      // Query manual para obtener ratings por fuente (usando author_institution)
      final ratingsWithSource = await _supabase
          .from('rating_items')
          .select('''
            assigned_reliability_score,
            news_items!inner(
              news_item_id,
              author_institution
            )
          ''');

      // Agrupar por fuente y calcular promedios
      final Map<String, List<double>> sourceRatings = {};
      
      for (final rating in ratingsWithSource) {
        final sourceName = rating['news_items']['author_institution'] as String? ?? 'Unknown';
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        sourceRatings.putIfAbsent(sourceName, () => []);
        sourceRatings[sourceName]!.add(reliability);
      }

      _sourceVeracityData = sourceRatings.entries.map((entry) {
        final ratings = entry.value;
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        
        return {
          'source_name': entry.key,
          'avg_reliability': avg,
          'total_ratings': ratings.length,
        };
      }).toList();

      // Ordenar por promedio descendente
      _sourceVeracityData.sort((a, b) => 
        (b['avg_reliability'] as double).compareTo(a['avg_reliability'] as double)
      );

      print('✅ BQ2 Source Veracity Analysis cargado (${_sourceVeracityData.length} fuentes)');
    } catch (e) {
      print('❌ Error en BQ2: $e');
      _sourceVeracityData = [];
    }
  }

  /// ✅ BQ3: Conversion rate analysis
  Future<void> _loadBQ3ConversionRateAnalysis() async {
    try {
      // Obtener usuarios que llegaron por artículos compartidos
      final sharedArticleUsers = await _supabase
          .from('engagement_events')
          .select('user_profile_id, news_item_id')
          .eq('event_type', 'article_shared')
          .eq('action', 'clicked');

      // Obtener usuarios activos (que han hecho ratings)
      final activeUsers = await _supabase
          .from('rating_items')
          .select('user_profile_id')
          .gt('assigned_reliability_score', 0);

      final totalSharedClicks = sharedArticleUsers.length;
      final uniqueSharedUsers = sharedArticleUsers
          .map((e) => e['user_profile_id'])
          .toSet()
          .length;

      final convertedUsers = sharedArticleUsers
          .where((shared) => activeUsers
              .any((active) => active['user_profile_id'] == shared['user_profile_id']))
          .map((e) => e['user_profile_id'])
          .toSet()
          .length;

      final conversionRate = uniqueSharedUsers > 0 
          ? (convertedUsers / uniqueSharedUsers) 
          : 0.0;

      _conversionRateData = {
        'total_shared': totalSharedClicks,
        'unique_users': uniqueSharedUsers,
        'rated_count': convertedUsers,
        'conversion_rate': conversionRate,
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ3 Conversion Rate Analysis cargado');
    } catch (e) {
      print('❌ Error en BQ3: $e');
      _conversionRateData = {
        'total_shared': 0,
        'rated_count': 0,
        'conversion_rate': 0.0,
      };
    }
  }

  /// ✅ BQ4: Rating distribution by category
  Future<void> _loadBQ4CategoryDistribution() async {
    try {
      // Query manual para obtener distribución por categoría
      final ratingsWithCategory = await _supabase
          .from('rating_items')
          .select('''
            assigned_reliability_score,
            news_items!inner(
              category_id,
              categories!inner(name)
            )
          ''');

      // Agrupar por categoría
      final Map<int, Map<String, dynamic>> categoryGroups = {};
      
      for (final rating in ratingsWithCategory) {
        final categoryId = rating['news_items']['category_id'] as int?;
        if (categoryId == null) continue; // Skip nulls
        
        final categoryName = rating['news_items']['categories']['name'] as String? ?? 'Unknown';
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        if (!categoryGroups.containsKey(categoryId)) {
          categoryGroups[categoryId] = {
            'category_id': categoryId,
            'category_name': categoryName,
            'ratings': <double>[],
          };
        }
        
        (categoryGroups[categoryId]!['ratings'] as List<double>).add(reliability);
      }

      _categoryDistributionData = categoryGroups.values.map((group) {
        final ratings = group['ratings'] as List<double>;
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        
        return {
          'category_id': group['category_id'],
          'category_name': group['category_name'],
          'rating_count': ratings.length,
          'avg_reliability': avg,
        };
      }).toList();

      // Ordenar por cantidad de ratings descendente
      _categoryDistributionData.sort((a, b) => 
        (b['rating_count'] as int).compareTo(a['rating_count'] as int)
      );

      print('✅ BQ4 Category Distribution cargado (${_categoryDistributionData.length} categorías)');
    } catch (e) {
      print('❌ Error en BQ4: $e');
      _categoryDistributionData = [];
    }
  }

  /// ✅ BQ5: Engagement vs accuracy correlation
  Future<void> _loadBQ5EngagementAccuracyCorrelation() async {
    try {
      // Obtener datos de sesiones con duración
      final sessionData = await _supabase
          .from('user_sessions')
          .select('user_session_id, duration_seconds, user_profile_id, articles_viewed')
          .gt('duration_seconds', 0);

      // Obtener ratings por sesión (agrupando por user_profile_id)
      final ratingData = await _supabase
          .from('rating_items')
          .select('user_profile_id, assigned_reliability_score');

      if (sessionData.isEmpty || ratingData.isEmpty) {
        _engagementAccuracyData = {
          'correlation': 0.0,
          'sample_size': 0,
          'message': 'Datos insuficientes para calcular correlación'
        };
        print('⚠️ BQ5: Datos insuficientes');
        return;
      }

      // Agrupar ratings por usuario para calcular accuracy
      final Map<int, List<double>> userRatings = {};
      for (final rating in ratingData) {
        final userId = rating['user_profile_id'] as int?;
        if (userId == null) continue; // Skip nulls
        
        final reliabilityRaw = rating['assigned_reliability_score'];
        if (reliabilityRaw == null) continue; // Skip nulls
        final reliability = (reliabilityRaw as num).toDouble();
        
        userRatings.putIfAbsent(userId, () => []);
        userRatings[userId]!.add(reliability);
      }

      // Calcular engagement y accuracy por usuario
      final List<Map<String, double>> userMetrics = [];
      
      // Agrupar sesiones por usuario
      final Map<int, List<Map<String, dynamic>>> userSessions = {};
      for (final session in sessionData) {
        final userId = session['user_profile_id'] as int?;
        if (userId == null) continue; // Skip nulls
        userSessions.putIfAbsent(userId, () => []);
        userSessions[userId]!.add(session);
      }

      for (final entry in userSessions.entries) {
        final userId = entry.key;
        final sessions = entry.value;
        
        if (userRatings.containsKey(userId) && userRatings[userId]!.isNotEmpty) {
          // Calcular engagement: suma de duration_seconds + articles_viewed
          final totalDuration = sessions
              .map((s) {
                final dur = s['duration_seconds'];
                if (dur == null) return 0.0;
                return (dur as num).toDouble();
              })
              .reduce((a, b) => a + b);
          final totalArticles = sessions
              .map((s) => (s['articles_viewed'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b);
          
          final engagementScore = totalDuration / 60.0 + (totalArticles * 5); // minutos + bonus por artículo
          
          // Calcular accuracy: promedio de reliability scores
          final avgAccuracy = userRatings[userId]!.reduce((a, b) => a + b) / userRatings[userId]!.length;
          
          userMetrics.add({
            'engagement': engagementScore,
            'accuracy': avgAccuracy,
          });
        }
      }

      // Calcular correlación de Pearson
      final correlation = _calculatePearsonCorrelation(userMetrics);

      _engagementAccuracyData = {
        'correlation': correlation,
        'sample_size': userMetrics.length,
        'avg_engagement': userMetrics.isEmpty ? 0.0 : 
          userMetrics.map((m) => m['engagement']!).reduce((a, b) => a + b) / userMetrics.length,
        'avg_accuracy': userMetrics.isEmpty ? 0.0 :
          userMetrics.map((m) => m['accuracy']!).reduce((a, b) => a + b) / userMetrics.length,
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('✅ BQ5 Engagement-Accuracy Correlation cargado (r=${correlation.toStringAsFixed(3)}, n=${userMetrics.length})');
    } catch (e) {
      print('❌ Error en BQ5: $e');
      _engagementAccuracyData = {
        'correlation': 0.0,
        'sample_size': 0,
      };
    }
  }

  /// Calcular correlación de Pearson entre engagement y accuracy
  double _calculatePearsonCorrelation(List<Map<String, double>> data) {
    if (data.length < 2) return 0.0;

    final engagements = data.map((d) => d['engagement']!).toList();
    final accuracies = data.map((d) => d['accuracy']!).toList();

    final n = data.length;
    final meanEngagement = engagements.reduce((a, b) => a + b) / n;
    final meanAccuracy = accuracies.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double sumSqEngagement = 0.0;
    double sumSqAccuracy = 0.0;

    for (int i = 0; i < n; i++) {
      final diffEngagement = engagements[i] - meanEngagement;
      final diffAccuracy = accuracies[i] - meanAccuracy;
      
      numerator += diffEngagement * diffAccuracy;
      sumSqEngagement += diffEngagement * diffEngagement;
      sumSqAccuracy += diffAccuracy * diffAccuracy;
    }

    final denominator = sqrt(sumSqEngagement * sumSqAccuracy);
    return denominator == 0 ? 0.0 : numerator / denominator;
  }

  // ⚠️ NUEVAS BUSINESS QUESTIONS (Milestone H)
  Map<String, dynamic> _bqH1DarkModeData = {}; // H.1: Dark mode usage
  List<Map<String, dynamic>> _bqH2NewsCreationData = []; // H.2: User contributions
  Map<String, dynamic> _bqH3PersonalizationData = {}; // H.3: Personalization ratio
  Map<String, dynamic> _bqH4UserActionsData = {}; // H.4: User awareness of actions
  List<Map<String, dynamic>> _bqH5SourceSatisfactionData = []; // H.5: Source satisfaction

  // Getters para las nuevas BQ
  Map<String, dynamic> get bqH1DarkModeData => _bqH1DarkModeData;
  List<Map<String, dynamic>> get bqH2NewsCreationData => _bqH2NewsCreationData;
  Map<String, dynamic> get bqH3PersonalizationData => _bqH3PersonalizationData;
  Map<String, dynamic> get bqH4UserActionsData => _bqH4UserActionsData;
  List<Map<String, dynamic>> get bqH5SourceSatisfactionData => _bqH5SourceSatisfactionData;

  /// ✅ H.1: Dark mode usage percentage
  Future<void> loadBQH1DarkModeUsage() async {
    try {
      final result = await _supabase.rpc('get_dark_mode_percentage');
      _bqH1DarkModeData = {
        'dark_mode_percentage': result ?? 0.0,
        'total_users': 0, // Placeholder, adjust based on RPC return
      };
      notifyListeners();
    } catch (e) {
      print('❌ Error loading BQ H.1: $e');
      _bqH1DarkModeData = {'error': e.toString()};
    }
  }

  /// ✅ H.2: News created by users per week
  Future<void> loadBQH2NewsCreation() async {
    try {
      final result = await _supabase
          .from('news_items')
          .select('user_profile_id, publication_date')
          .order('publication_date', ascending: false)
          .limit(1000); // Last 1000 articles

      // Group by week
      final weeklyData = <String, int>{};
      for (var item in result) {
        final date = DateTime.parse(item['publication_date'] as String);
        final weekKey = '${date.year}-W${_getWeekNumber(date)}';
        weeklyData[weekKey] = (weeklyData[weekKey] ?? 0) + 1;
      }

      _bqH2NewsCreationData = weeklyData.entries
          .map((e) => {'week': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (a['week'] as String).compareTo(b['week'] as String));

      notifyListeners();
    } catch (e) {
      print('❌ Error loading BQ H.2: $e');
    }
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear = int.parse(date.difference(DateTime(date.year, 1, 1)).inDays.toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// ✅ H.3: Personalization ratio (favorite categories shown)
  Future<void> loadBQH3Personalization() async {
    try {
      // Get current user's profile
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) return;

      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_profile_id')
          .eq('user_auth_id', authUserId)
          .maybeSingle();

      if (userProfile == null) return;
      final userProfileId = userProfile['user_profile_id'] as int;

      // Get user's favorite categories
      final favorites = await _supabase
          .from('user_favorite_categories')
          .select('category_id')
          .eq('user_profile_id', userProfileId);

      final favCategoryIds = favorites.map((f) => f['category_id'] as int).toList();

      // Get user's session impressions
      final sessions = await _supabase
          .from('user_sessions')
          .select('user_session_id')
          .eq('user_profile_id', userProfileId)
          .limit(10); // Last 10 sessions

      int totalImpressions = 0;
      int favoriteImpressions = 0;

      for (var session in sessions) {
        final viewed = await _supabase
            .from('viewed_categories')
            .select('category_id')
            .eq('user_session_id', session['user_session_id']);

        totalImpressions += viewed.length;
        favoriteImpressions += viewed.where((v) => favCategoryIds.contains(v['category_id'])).length;
      }

      final personalizationRatio = totalImpressions > 0
          ? (favoriteImpressions / totalImpressions) * 100
          : 0.0;

      _bqH3PersonalizationData = {
        'personalization_ratio': personalizationRatio,
        'total_impressions': totalImpressions,
        'favorite_impressions': favoriteImpressions,
      };

      notifyListeners();
    } catch (e) {
      print('❌ Error loading BQ H.3: $e');
    }
  }

  /// ✅ H.4: User actions awareness (ratings, comments, reads)
  Future<void> loadBQH4UserActions() async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) return;

      final userProfile = await _supabase
          .from('user_profiles')
          .select('user_profile_id')
          .eq('user_auth_id', authUserId)
          .maybeSingle();

      if (userProfile == null) return;
      final userProfileId = userProfile['user_profile_id'] as int;

      // Count ratings
      final ratings = await _supabase
          .from('rating_items')
          .select('rating_item_id')
          .eq('user_profile_id', userProfileId);

      // Count comments
      final comments = await _supabase
          .from('comments')
          .select('comment_id')
          .eq('user_profile_id', userProfileId);

      // Count reads (from news_read_history)
      final reads = await _supabase
          .from('news_read_history')
          .select('read_id')
          .eq('user_profile_id', userProfileId);

      _bqH4UserActionsData = {
        'ratings_count': ratings.length,
        'comments_count': comments.length,
        'reads_count': reads.length,
        'total_actions': ratings.length + comments.length + reads.length,
      };

      notifyListeners();
    } catch (e) {
      print('❌ Error loading BQ H.4: $e');
    }
  }

  /// ✅ H.5: Source satisfaction by category (lowest rated)
  Future<void> loadBQH5SourceSatisfaction() async {
    try {
      final result = await _supabase
          .from('news_items')
          .select('source_domain, category_id, news_item_id')
          .not('source_domain', 'is', null)
          .limit(500);

      // Get ratings for these articles
      final Map<String, Map<String, dynamic>> sourceStats = {};

      for (var item in result) {
        final source = item['source_domain'] as String?;
        final category = item['category_id'] as int?;
        final newsId = item['news_item_id'] as int;

        if (source == null || category == null) continue;

        final key = '$source-$category';

        // Get ratings for this article
        final ratings = await _supabase
            .from('rating_items')
            .select('assigned_reliability_score')
            .eq('news_item_id', newsId);

        if (ratings.isEmpty) continue;

        final avgScore = ratings
                .map((r) => (r['assigned_reliability_score'] as num).toDouble())
                .reduce((a, b) => a + b) /
            ratings.length;

        if (!sourceStats.containsKey(key)) {
          sourceStats[key] = {
            'source': source,
            'category': category,
            'total_score': 0.0,
            'count': 0,
          };
        }

        sourceStats[key]!['total_score'] = (sourceStats[key]!['total_score'] as double) + avgScore;
        sourceStats[key]!['count'] = (sourceStats[key]!['count'] as int) + 1;
      }

      // Calculate averages and sort
      _bqH5SourceSatisfactionData = sourceStats.entries
          .map((e) {
            final avg = (e.value['total_score'] as double) / (e.value['count'] as int);
            return {
              'source': e.value['source'],
              'category': e.value['category'],
              'avg_score': avg,
              'count': e.value['count'],
            };
          })
          .toList()
        ..sort((a, b) => (a['avg_score'] as double).compareTo(b['avg_score'] as double));

      // Keep only lowest 10
      if (_bqH5SourceSatisfactionData.length > 10) {
        _bqH5SourceSatisfactionData = _bqH5SourceSatisfactionData.sublist(0, 10);
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error loading BQ H.5: $e');
    }
  }

  /// ✅ STREAMS EN TIEMPO REAL
  void _startRealTimeUpdates() {
    // Rating updates para BQ1 y BQ4
    _ratingsStream?.cancel();
    _ratingsStream = _supabase
        .from('rating_items')
        .stream(primaryKey: ['rating_item_id'])
        .listen((data) {
      print('📊 Ratings actualizados en tiempo real');
      // Re-calcular BQ1 y BQ4 cuando hay nuevos ratings
      _loadBQ1PersonalBiasScore(null);
      _loadBQ4CategoryDistribution();
    });

    // Session updates para BQ3 y BQ5
    _sessionsStream?.cancel();
    _sessionsStream = _supabase
        .from('user_sessions')
        .stream(primaryKey: ['session_id'])
        .listen((data) {
      print('📊 Sesiones actualizadas en tiempo real');
      _loadBQ5EngagementAccuracyCorrelation();
    });

    // Engagement updates para BQ3
    _engagementStream?.cancel();
    _engagementStream = _supabase
        .from('engagement_events')
        .stream(primaryKey: ['event_id'])
        .listen((data) {
      print('📊 Engagement actualizado en tiempo real');
      _loadBQ3ConversionRateAnalysis();
    });
  }

  @override
  void dispose() {
    _ratingsStream?.cancel();
    _sessionsStream?.cancel();
    _engagementStream?.cancel();
    super.dispose();
  }
}
