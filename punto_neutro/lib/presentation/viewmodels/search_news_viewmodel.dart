// =====================================================
// ViewModel: Search News
// Purpose: Manage news search state and operations
// Features: FTS, autocomplete, category filter, sort
// =====================================================

import 'package:flutter/foundation.dart';
import '../../domain/models/news_item.dart';
import '../../domain/repositories/news_repository.dart';

enum SearchSortOrder {
  relevance, // Default: sort by FTS rank
  dateDesc, // Newest first
  dateAsc, // Oldest first
}

class SearchNewsViewModel extends ChangeNotifier {
  final NewsRepository _repository;

  SearchNewsViewModel({
    required NewsRepository repository,
  }) : _repository = repository;

  // State
  List<NewsItem> _searchResults = [];
  List<String> _suggestions = [];
  String _query = '';
  String? _categoryFilter;
  SearchSortOrder _sortOrder = SearchSortOrder.relevance;
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  String? _error;
  bool _hasSearched = false;

  // Getters
  List<NewsItem> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  String get query => _query;
  String? get categoryFilter => _categoryFilter;
  SearchSortOrder get sortOrder => _sortOrder;
  bool get isSearching => _isSearching;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  String? get error => _error;
  bool get hasResults => _searchResults.isNotEmpty;
  bool get hasSearched => _hasSearched;
  int get resultsCount => _searchResults.length;

  /// Update search query
  void updateQuery(String value) {
    _query = value;
    _error = null;
    notifyListeners();

    // Load suggestions for non-empty queries
    if (value.trim().isNotEmpty && value.length >= 2) {
      _loadSuggestions(value);
    } else {
      _suggestions.clear();
      notifyListeners();
    }
  }

  /// Set category filter
  void setCategoryFilter(String? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();

    // Re-search if we already have a query
    if (_query.trim().isNotEmpty) {
      search(_query);
    }
  }

  /// Set sort order
  void setSortOrder(SearchSortOrder order) {
    _sortOrder = order;
    notifyListeners();

    // Re-sort current results
    if (_searchResults.isNotEmpty) {
      _sortResults();
      notifyListeners();
    }
  }

  /// Clear category filter
  void clearCategoryFilter() {
    setCategoryFilter(null);
  }

  /// Perform search
  Future<void> search(String searchQuery) async {
    if (searchQuery.trim().isEmpty) {
      _clearResults();
      return;
    }

    _isSearching = true;
    _error = null;
    _hasSearched = true;
    notifyListeners();

    try {
      // TODO: Call repository search method with FTS
      // For now, simulate search with getNewsList() and filter
      await Future.delayed(const Duration(milliseconds: 500));
      
      final allNews = await _repository.getNewsList();
      
      // Simple client-side filtering (replace with server FTS later)
      final lowerQuery = searchQuery.toLowerCase();
      _searchResults = allNews.where((news) {
        final matchesQuery = news.title.toLowerCase().contains(lowerQuery) ||
            news.short_description.toLowerCase().contains(lowerQuery);
        
        final matchesCategory = _categoryFilter == null ||
            news.category_id == _categoryFilter;
        
        return matchesQuery && matchesCategory;
      }).toList();

      _sortResults();
      _error = null;
    } catch (e) {
      _error = 'Error al buscar: $e';
      _searchResults.clear();
      print('Error searching: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Load title suggestions (autocomplete)
  Future<void> _loadSuggestions(String prefix) async {
    if (prefix.length < 2) {
      _suggestions.clear();
      return;
    }

    _isLoadingSuggestions = true;

    try {
      // TODO: Call get_title_suggestions() SQL function
      // For now, simulate with simple prefix matching
      await Future.delayed(const Duration(milliseconds: 200));
      
      final allNews = await _repository.getNewsList();
      final lowerPrefix = prefix.toLowerCase();
      
      _suggestions = allNews
          .where((news) => news.title.toLowerCase().startsWith(lowerPrefix))
          .map((news) => news.title)
          .take(5)
          .toList();
    } catch (e) {
      print('Error loading suggestions: $e');
      _suggestions.clear();
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Sort results based on current sort order
  void _sortResults() {
    switch (_sortOrder) {
      case SearchSortOrder.relevance:
        // For FTS, this would use ts_rank from SQL
        // For now, keep original order
        break;
      case SearchSortOrder.dateDesc:
        _searchResults.sort((a, b) =>
            b.publication_date.compareTo(a.publication_date));
        break;
      case SearchSortOrder.dateAsc:
        _searchResults.sort((a, b) =>
            a.publication_date.compareTo(b.publication_date));
        break;
    }
  }

  /// Clear search results
  void _clearResults() {
    _searchResults.clear();
    _hasSearched = false;
    _error = null;
    notifyListeners();
  }

  /// Clear all search state
  void clearSearch() {
    _query = '';
    _searchResults.clear();
    _suggestions.clear();
    _categoryFilter = null;
    _sortOrder = SearchSortOrder.relevance;
    _hasSearched = false;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get sort order display name
  String getSortOrderName(SearchSortOrder order) {
    switch (order) {
      case SearchSortOrder.relevance:
        return 'Relevancia';
      case SearchSortOrder.dateDesc:
        return 'Más recientes';
      case SearchSortOrder.dateAsc:
        return 'Más antiguas';
    }
  }
}
