// =====================================================
// Screen: Search News
// Purpose: Search news with FTS, filters, and autocomplete
// Features: Search bar, suggestions, category filter, sort
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/search_news_viewmodel.dart';
import '../../data/repositories/categories_repository.dart';
import '../../domain/models/news_item.dart';
import '../../data/repositories/hybrid_news_repository.dart';
import '../../data/repositories/local_news_repository.dart';
import 'news_detail_screen.dart';

class SearchNewsScreen extends StatelessWidget {
  const SearchNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchNewsViewModel(
        repository: HybridNewsRepository(),
      ),
      child: const _SearchNewsContent(),
    );
  }
}

class _SearchNewsContent extends StatefulWidget {
  const _SearchNewsContent();

  @override
  State<_SearchNewsContent> createState() => _SearchNewsScreenState();
}

class _SearchNewsScreenState extends State<_SearchNewsContent> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to focus changes
    _focusNode.addListener(() {
      setState(() {
        _showSuggestions = _focusNode.hasFocus && _searchController.text.length >= 2;
      });
    });

    // Listen to text changes
    _searchController.addListener(() {
      final viewModel = context.read<SearchNewsViewModel>();
      viewModel.updateQuery(_searchController.text);
      setState(() {
        _showSuggestions = _focusNode.hasFocus && _searchController.text.length >= 2;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Noticias'),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Filters and sort
          _buildFilterBar(),

          // Results or empty state
          Expanded(
            child: Consumer<SearchNewsViewModel>(
              builder: (context, viewModel, _) {
                return Stack(
                  children: [
                    // Main content
                    _buildMainContent(viewModel),

                    // Suggestions overlay
                    if (_showSuggestions && viewModel.suggestions.isNotEmpty)
                      _buildSuggestionsOverlay(viewModel),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Buscar noticias...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchNewsViewModel>().clearSearch();
                    _focusNode.unfocus();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            context.read<SearchNewsViewModel>().search(value);
            _focusNode.unfocus();
            setState(() => _showSuggestions = false);
          }
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Consumer<SearchNewsViewModel>(
      builder: (context, viewModel, _) {
        final categories = CategoriesRepository.categories;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: viewModel.categoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ...categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.category_id,
                        child: Text(cat.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    viewModel.setCategoryFilter(value);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Sort order
              PopupMenuButton<SearchSortOrder>(
                icon: const Icon(Icons.sort),
                tooltip: 'Ordenar',
                onSelected: (order) => viewModel.setSortOrder(order),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SearchSortOrder.relevance,
                    child: Row(
                      children: [
                        if (viewModel.sortOrder == SearchSortOrder.relevance)
                          const Icon(Icons.check, size: 20),
                        if (viewModel.sortOrder == SearchSortOrder.relevance)
                          const SizedBox(width: 8),
                        const Text('Relevancia'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SearchSortOrder.dateDesc,
                    child: Row(
                      children: [
                        if (viewModel.sortOrder == SearchSortOrder.dateDesc)
                          const Icon(Icons.check, size: 20),
                        if (viewModel.sortOrder == SearchSortOrder.dateDesc)
                          const SizedBox(width: 8),
                        const Text('Más recientes'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SearchSortOrder.dateAsc,
                    child: Row(
                      children: [
                        if (viewModel.sortOrder == SearchSortOrder.dateAsc)
                          const Icon(Icons.check, size: 20),
                        if (viewModel.sortOrder == SearchSortOrder.dateAsc)
                          const SizedBox(width: 8),
                        const Text('Más antiguas'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(SearchNewsViewModel viewModel) {
    // Loading state
    if (viewModel.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (viewModel.error != null) {
      return _buildErrorState(viewModel.error!);
    }

    // No search performed yet
    if (!viewModel.hasSearched) {
      return _buildEmptyState();
    }

    // No results
    if (!viewModel.hasResults) {
      return _buildNoResultsState();
    }

    // Results list
    return Column(
      children: [
        // Results count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            '${viewModel.resultsCount} resultado${viewModel.resultsCount != 1 ? 's' : ''} encontrado${viewModel.resultsCount != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Results list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: viewModel.searchResults.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final newsItem = viewModel.searchResults[index];
              return _buildNewsItemTile(newsItem);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsOverlay(SearchNewsViewModel viewModel) {
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: viewModel.suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final suggestion = viewModel.suggestions[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.search, size: 20),
                title: Text(
                  suggestion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  _searchController.text = suggestion;
                  viewModel.search(suggestion);
                  _focusNode.unfocus();
                  setState(() => _showSuggestions = false);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNewsItemTile(NewsItem newsItem) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[300],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: newsItem.image_url.isNotEmpty
              ? Image.network(
                  newsItem.image_url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                )
              : const Icon(Icons.article, size: 40),
        ),
      ),
      title: Text(
        newsItem.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            newsItem.short_description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _formatDate(newsItem.publication_date),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(width: 12),
              Icon(Icons.star, size: 12, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${(newsItem.average_reliability_score * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        // TODO: Navigate to news detail
        _navigateToNewsDetail(newsItem.news_item_id);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Busca noticias',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe palabras clave para encontrar noticias',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No se encontraron resultados',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otras palabras clave',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              context.read<SearchNewsViewModel>().clearSearch();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Nueva búsqueda'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final viewModel = context.read<SearchNewsViewModel>();
              if (viewModel.query.isNotEmpty) {
                viewModel.search(viewModel.query);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inMinutes}min';
    }
  }

  void _navigateToNewsDetail(String newsItemId) {
    // Navigate to news detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(
          news_item_id: newsItemId,
          repository: LocalNewsRepository(),
        ),
      ),
    );
  }
}
