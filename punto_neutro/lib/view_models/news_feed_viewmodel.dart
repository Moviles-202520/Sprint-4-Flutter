import 'package:flutter/foundation.dart';
import '../core/image_cache_service.dart';
import '../domain/repositories/news_repository.dart';
import '../domain/models/news_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ⚠️ NUEVO: Para Realtime

class NewsFeedViewModel extends ChangeNotifier {
  final NewsRepository _repository;
  
  List<NewsItem> _allNewsItems = [];
  List<NewsItem> _filteredNewsItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentIndex = 0;
  String? _selectedCategoryId;
  RealtimeChannel? _newsChannel; // ⚠️ NUEVO: Canal de Realtime
  
  // Paginación
  static const int _pageSize = 20;
  int _currentPage = 0;

  NewsFeedViewModel(this._repository) {
    _loadNews();
    _subscribeToNewsUpdates(); // ⚠️ NUEVO: Escuchar cambios en tiempo real
  }
  
  // ⚠️ NUEVO: Suscribirse a cambios en news_items
  void _subscribeToNewsUpdates() {
    try {
      _newsChannel = Supabase.instance.client
          .channel('news_feed_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'news_items',
            callback: (payload) {
              print('🆕 [REALTIME] Nueva noticia creada, recargando feed...');
              _loadNews(); // Recargar feed automáticamente
            },
          )
          .subscribe();
      
      print('👂 [REALTIME] Escuchando cambios en news_items');
    } catch (e) {
      print('⚠️ [REALTIME] Error suscribiendo a cambios: $e');
    }
  }
  
  @override
  void dispose() {
    _newsChannel?.unsubscribe(); // ⚠️ NUEVO: Limpiar suscripción
    super.dispose();
  }

  List<NewsItem> get newsItems => _filteredNewsItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  int get currentIndex => _currentIndex;
  String? get selectedCategoryId => _selectedCategoryId;

  Future<void> _loadNews() async {
    try {
      _isLoading = true;
      _currentPage = 0;
      _hasMoreData = true;
      notifyListeners();
      print('🔄 Cargando noticias (página inicial)...');
      final loadedNews = await _repository.getNewsList();
      _allNewsItems = loadedNews;
      _applyCategoryFilter(reset: true);
      print('📊 Total disponible: ${_allNewsItems.length} noticias');
      print('📄 Mostrando página 1: ${_filteredNewsItems.length} items');
    } catch (e) {
      print('❌ Error cargando feed: $e');
      _allNewsItems = [];
      _filteredNewsItems = [];
      _hasMoreData = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNews() async {
    if (_isLoadingMore || !_hasMoreData || _isLoading) return;
    
    try {
      _isLoadingMore = true;
      notifyListeners();
      
      _currentPage++;
      print('📄 Cargando página ${_currentPage + 1}...');
      
      // Aplicar filtro con la nueva página
      _applyCategoryFilter(reset: false);
      
      print('📊 Ahora mostrando ${_filteredNewsItems.length} items en total');
      
    } catch (e) {
      print('❌ Error cargando más noticias: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void refreshNews() {
    _loadNews();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryId = categoryId;
    _currentPage = 0;
    _hasMoreData = true;
    _applyCategoryFilter(reset: true);
    notifyListeners();
  }

  void _applyCategoryFilter({bool reset = false}) {
    List<NewsItem> sourceList;
    
    if (_selectedCategoryId == null || _selectedCategoryId == 'all') {
      sourceList = List.from(_allNewsItems);
    } else {
      sourceList = _allNewsItems.where((item) => item.category_id == _selectedCategoryId).toList();
    }
    
    if (reset) {
      // Reset: mostrar solo la primera página
      final endIndex = _pageSize > sourceList.length ? sourceList.length : _pageSize;
      _filteredNewsItems = sourceList.sublist(0, endIndex);
      _hasMoreData = endIndex < sourceList.length;
    } else {
      // Agregar siguiente página
      final startIndex = (_currentPage) * _pageSize;
      final endIndex = (startIndex + _pageSize) > sourceList.length 
          ? sourceList.length 
          : startIndex + _pageSize;
      
      if (startIndex < sourceList.length) {
        _filteredNewsItems.addAll(sourceList.sublist(startIndex, endIndex));
        _hasMoreData = endIndex < sourceList.length;
      } else {
        _hasMoreData = false;
      }
    }
  }

  bool _prefetching = false;
  DateTime _lastPrefetch = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastPrefetchedEnd = 0;

  // Llamar cuando estés cerca del final del scroll
  Future<void> prefetchTail({int batch = 16}) async {
    if (_prefetching) return;
    if (DateTime.now().difference(_lastPrefetch).inMilliseconds < 1200) return;

    final list = _filteredNewsItems; // usa aquí el nombre real de tu lista
    if (list.isEmpty) return;

    final start = _lastPrefetchedEnd;
    final end = (start + batch > list.length) ? list.length : start + batch;
    if (start >= end) return;

    final urls = <String>[];
    for (var i = start; i < end; i++) {
      final u = list[i].image_url; // ajusta si tu modelo usa otro nombre
      if (u.isNotEmpty) urls.add(u);
    }
    if (urls.isEmpty) {
      _lastPrefetchedEnd = end;
      return;
    }

    _prefetching = true;
    try {
      await ImageCacheService.instance.prefetchUrls(
        urls,
        concurrency: 4,
        maxBytesBudget: 50 * 1024 * 1024,
        maxFilesBudget: 400,
      );
      _lastPrefetch = DateTime.now();
      _lastPrefetchedEnd = end;
    } finally {
      _prefetching = false;
    }
  }
}
