// =====================================================
// Screen: PreferencesScreen (G.1)
// Purpose: User preferences UI for customization
// Features: Dark mode, notifications, language, favorite categories
// Dependencies: PreferencesViewModel, CategoriesRepository
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../viewmodels/preferences_viewmodel.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../../data/repositories/categories_repository.dart';
import '../../data/repositories/supabase_user_preferences_repository.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get userProfileId from AuthViewModel
    final userProfileId = context.read<AuthViewModel>().userProfileId ?? 1;
    // Get ThemeViewModel from context
    final themeViewModel = context.read<ThemeViewModel>();
    
    return ChangeNotifierProvider(
      create: (_) => PreferencesViewModel(
        repository: SupabaseUserPreferencesRepository(Supabase.instance.client),
        userProfileId: userProfileId,
        themeViewModel: themeViewModel,
      ),
      child: const _PreferencesContent(),
    );
  }
}

class _PreferencesContent extends StatefulWidget {
  const _PreferencesContent();

  @override
  State<_PreferencesContent> createState() => _PreferencesContentState();
}

class _PreferencesContentState extends State<_PreferencesContent> {
  @override
  void initState() {
    super.initState();
    // Load preferences on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferencesViewModel>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferencias'),
        elevation: 0,
      ),
      body: Consumer<PreferencesViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar preferencias',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => viewModel.loadPreferences(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // App Appearance Section
              _buildSectionHeader(context, 'Apariencia'),
              _buildDarkModeSwitch(context, viewModel),
              const Divider(),

              // Notifications Section
              _buildSectionHeader(context, 'Notificaciones'),
              _buildNotificationsSwitch(context, viewModel),
              const Divider(),

              // Language Section
              _buildSectionHeader(context, 'Idioma'),
              _buildLanguageSelector(context, viewModel),
              const Divider(),

              // Favorite Categories Section
              _buildSectionHeader(context, 'Categorías Favoritas'),
              _buildFavoriteCategoriesSection(context, viewModel),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildDarkModeSwitch(
      BuildContext context, PreferencesViewModel viewModel) {
    return SwitchListTile(
      title: const Text('Modo Oscuro'),
      subtitle: const Text('Apariencia oscura de la app'),
      secondary: Icon(
        viewModel.darkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.primary,
      ),
      value: viewModel.darkMode,
      onChanged: viewModel.isSaving ? null : (_) => viewModel.toggleDarkMode(),
    );
  }

  Widget _buildNotificationsSwitch(
      BuildContext context, PreferencesViewModel viewModel) {
    return SwitchListTile(
      title: const Text('Notificaciones'),
      subtitle: const Text('Recibir notificaciones de la app'),
      secondary: Icon(
        viewModel.notificationsEnabled
            ? Icons.notifications_active
            : Icons.notifications_off,
        color: Theme.of(context).colorScheme.primary,
      ),
      value: viewModel.notificationsEnabled,
      onChanged:
          viewModel.isSaving ? null : (_) => viewModel.toggleNotifications(),
    );
  }

  Widget _buildLanguageSelector(
      BuildContext context, PreferencesViewModel viewModel) {
    return ListTile(
      leading: Icon(
        Icons.language,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Idioma'),
      subtitle: Text(_getLanguageName(viewModel.language)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: viewModel.isSaving ? null : () => _showLanguageDialog(context, viewModel),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }

  void _showLanguageDialog(
      BuildContext context, PreferencesViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'es',
              groupValue: viewModel.language,
              onChanged: (value) {
                if (value != null) {
                  viewModel.changeLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: viewModel.language,
              onChanged: (value) {
                if (value != null) {
                  viewModel.changeLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCategoriesSection(
      BuildContext context, PreferencesViewModel viewModel) {
    final categories = CategoriesRepository.categories;
    
    return Column(
      children: categories.map((category) {
        final categoryId = int.parse(category.category_id);
        final isFavorite = viewModel.isFavorite(categoryId);
        return CheckboxListTile(
          title: Text(category.name),
          subtitle: Text('${category.name} personalizado en tu feed'),
          secondary: Icon(
            _getCategoryIcon(category.name),
            color: isFavorite
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          value: isFavorite,
          onChanged: viewModel.isSaving
              ? null
              : (_) => viewModel.toggleFavoriteCategory(
                    categoryId,
                    category.name,
                  ),
        );
      }).toList(),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'politics':
      case 'política':
        return Icons.account_balance;
      case 'sports':
      case 'deportes':
        return Icons.sports_soccer;
      case 'science':
      case 'ciencia':
        return Icons.science;
      case 'economics':
      case 'economía':
        return Icons.attach_money;
      case 'business':
      case 'negocios':
        return Icons.business;
      case 'climate':
      case 'clima':
        return Icons.wb_sunny;
      case 'conflict':
      case 'conflicto':
        return Icons.warning;
      case 'local':
        return Icons.location_on;
      default:
        return Icons.category;
    }
  }
}
