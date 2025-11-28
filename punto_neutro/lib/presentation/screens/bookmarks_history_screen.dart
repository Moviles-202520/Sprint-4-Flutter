// =====================================================
// Screen: Bookmarks & Reading History
// Purpose: Display user's bookmarks and reading history
// Features: Tabs, delete, clear history, navigation
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bookmarks_history_viewmodel.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/models/reading_history.dart';

class BookmarksHistoryScreen extends StatefulWidget {
  const BookmarksHistoryScreen({super.key});

  @override
  State<BookmarksHistoryScreen> createState() => _BookmarksHistoryScreenState();
}

class _BookmarksHistoryScreenState extends State<BookmarksHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load data on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<BookmarksHistoryViewModel>();
      viewModel.loadBookmarks();
      viewModel.loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marcadores e Historial'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Marcadores', icon: Icon(Icons.bookmark)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookmarksTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ============================================
  // BOOKMARKS TAB
  // ============================================

  Widget _buildBookmarksTab() {
    return Consumer<BookmarksHistoryViewModel>(
      builder: (context, viewModel, _) {
        // Loading state
        if (viewModel.isLoadingBookmarks) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (viewModel.bookmarksError != null) {
          return _buildErrorState(
            error: viewModel.bookmarksError!,
            onRetry: () => viewModel.loadBookmarks(),
          );
        }

        // Empty state
        if (!viewModel.hasBookmarks) {
          return _buildEmptyState(
            icon: Icons.bookmark_border,
            message: 'No tienes marcadores',
            subtitle: 'Guarda artículos para leerlos más tarde',
          );
        }

        // Bookmarks list
        return RefreshIndicator(
          onRefresh: () => viewModel.refreshBookmarks(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: viewModel.bookmarks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bookmark = viewModel.bookmarks[index];
              return _buildBookmarkTile(context, viewModel, bookmark);
            },
          ),
        );
      },
    );
  }

  Widget _buildBookmarkTile(
    BuildContext context,
    BookmarksHistoryViewModel viewModel,
    Bookmark bookmark,
  ) {
    return Dismissible(
      key: Key('bookmark_${bookmark.bookmarkId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _showDeleteBookmarkDialog(context),
      onDismissed: (_) {
        viewModel.removeBookmark(bookmark.newsItemId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcador eliminado')),
        );
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bookmark,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text('Noticia #${bookmark.newsItemId}'),
        subtitle: Text(
          'Guardado ${viewModel.formatRelativeDate(bookmark.createdAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await _showDeleteBookmarkDialog(context);
            if (confirmed == true && context.mounted) {
              await viewModel.removeBookmark(bookmark.newsItemId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marcador eliminado')),
                );
              }
            }
          },
        ),
        onTap: () {
          // TODO: Navigate to news detail screen
          _navigateToNewsDetail(context, bookmark.newsItemId);
        },
      ),
    );
  }

  // ============================================
  // HISTORY TAB
  // ============================================

  Widget _buildHistoryTab() {
    return Consumer<BookmarksHistoryViewModel>(
      builder: (context, viewModel, _) {
        // Loading state
        if (viewModel.isLoadingHistory) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (viewModel.historyError != null) {
          return _buildErrorState(
            error: viewModel.historyError!,
            onRetry: () => viewModel.loadHistory(),
          );
        }

        // Empty state
        if (!viewModel.hasHistory) {
          return _buildEmptyState(
            icon: Icons.history,
            message: 'No hay historial de lectura',
            subtitle: 'Tus artículos leídos aparecerán aquí',
          );
        }

        // History list
        return Column(
          children: [
            // Stats header
            _buildHistoryStats(viewModel),
            
            // Clear history button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Text('Limpiar historial antiguo'),
                  const Spacer(),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (days) => _showClearOldHistoryDialog(context, viewModel, days),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 7, child: Text('Más de 7 días')),
                      const PopupMenuItem(value: 30, child: Text('Más de 30 días')),
                      const PopupMenuItem(value: 90, child: Text('Más de 90 días')),
                      const PopupMenuItem(value: 0, child: Text('Todo el historial')),
                    ],
                  ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => viewModel.refreshHistory(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: viewModel.history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final entry = viewModel.history[index];
                    return _buildHistoryTile(context, viewModel, entry);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryStats(BookmarksHistoryViewModel viewModel) {
    return FutureBuilder<Map<String, int>>(
      future: Future.wait([
        viewModel.getTotalReadingTime(),
        viewModel.getArticlesReadCount(),
      ]).then((results) => {
        'totalTime': results[0],
        'articlesCount': results[1],
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final totalTime = snapshot.data!['totalTime']!;
        final articlesCount = snapshot.data!['articlesCount']!;

        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.article,
                label: 'Artículos leídos',
                value: articlesCount.toString(),
                color: Theme.of(context).colorScheme.primary,
              ),
              _buildStatItem(
                icon: Icons.schedule,
                label: 'Tiempo de lectura',
                value: viewModel.formatDuration(totalTime),
                color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(
    BuildContext context,
    BookmarksHistoryViewModel viewModel,
    ReadingHistory entry,
  ) {
    return Dismissible(
      key: Key('history_${entry.readId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _showDeleteHistoryDialog(context),
      onDismissed: (_) {
        if (entry.readId != null) {
          viewModel.deleteHistoryEntry(entry.readId!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrada eliminada del historial')),
          );
        }
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.article, color: Colors.blue),
        ),
        title: Text('Noticia #${entry.newsItemId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  viewModel.formatDuration(entry.durationSeconds),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  viewModel.formatRelativeDate(entry.startedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (entry.readId == null) return;
            
            final confirmed = await _showDeleteHistoryDialog(context);
            if (confirmed == true && context.mounted) {
              await viewModel.deleteHistoryEntry(entry.readId!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entrada eliminada del historial')),
                );
              }
            }
          },
        ),
        onTap: () {
          // TODO: Navigate to news detail screen
          _navigateToNewsDetail(context, entry.newsItemId);
        },
      ),
    );
  }

  // ============================================
  // COMMON WIDGETS
  // ============================================

  Widget _buildErrorState({
    required String error,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ============================================
  // DIALOGS
  // ============================================

  Future<bool?> _showDeleteBookmarkDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar marcador'),
        content: const Text('¿Estás seguro de que quieres eliminar este marcador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteHistoryDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar del historial'),
        content: const Text('¿Estás seguro de que quieres eliminar esta entrada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearOldHistoryDialog(
    BuildContext context,
    BookmarksHistoryViewModel viewModel,
    int daysOld,
  ) async {
    final message = daysOld == 0
        ? '¿Estás seguro de que quieres eliminar TODO el historial? Esta acción no se puede deshacer.'
        : '¿Eliminar entradas del historial de más de $daysOld días?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (daysOld == 0) {
        await viewModel.clearAllHistory();
      } else {
        await viewModel.deleteOldHistory(daysOld);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial limpiado')),
        );
      }
    }
  }

  // ============================================
  // NAVIGATION
  // ============================================

  void _navigateToNewsDetail(BuildContext context, int newsItemId) {
    // TODO: Implement navigation to news detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navegar a noticia #$newsItemId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
