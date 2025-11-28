// =====================================================
// Screen: Create/Edit News
// Purpose: Form to create and publish news articles
// Features: Validation, draft saving, preview, publishing
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/create_news_viewmodel.dart';
import '../../data/repositories/categories_repository.dart';

class CreateNewsScreen extends StatefulWidget {
  final String? newsItemId; // null for create, set for edit

  const CreateNewsScreen({
    super.key,
    this.newsItemId,
  });

  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _institutionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Load existing news if editing
    if (widget.newsItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CreateNewsViewModel>().loadNewsForEditing(widget.newsItemId!);
      });
    }

    // Listen to ViewModel changes and update controllers
    _setupControllerListeners();
  }

  void _setupControllerListeners() {
    _titleController.addListener(() {
      context.read<CreateNewsViewModel>().updateTitle(_titleController.text);
    });
    _shortDescController.addListener(() {
      context.read<CreateNewsViewModel>().updateShortDescription(_shortDescController.text);
    });
    _longDescController.addListener(() {
      context.read<CreateNewsViewModel>().updateLongDescription(_longDescController.text);
    });
    _imageUrlController.addListener(() {
      context.read<CreateNewsViewModel>().updateImageUrl(_imageUrlController.text);
    });
    _sourceUrlController.addListener(() {
      context.read<CreateNewsViewModel>().updateOriginalSourceUrl(_sourceUrlController.text);
    });
    _institutionController.addListener(() {
      context.read<CreateNewsViewModel>().updateAuthorInstitution(_institutionController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _imageUrlController.dispose();
    _sourceUrlController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.newsItemId == null ? 'Crear Noticia' : 'Editar Noticia'),
        actions: [
          // Save as draft button
          Consumer<CreateNewsViewModel>(
            builder: (context, viewModel, _) {
              return TextButton.icon(
                onPressed: viewModel.isSaving ? null : () => _saveAsDraft(viewModel),
                icon: viewModel.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Borrador'),
              );
            },
          ),
        ],
      ),
      body: Consumer<CreateNewsViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            children: [
              // Error/Success message banner
              if (viewModel.error != null)
                _buildMessageBanner(
                  message: viewModel.error!,
                  isError: true,
                  onDismiss: () => viewModel.clearError(),
                ),
              if (viewModel.successMessage != null)
                _buildMessageBanner(
                  message: viewModel.successMessage!,
                  isError: false,
                  onDismiss: () => viewModel.clearSuccessMessage(),
                ),

              // Form content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Title field
                      _buildTitleField(viewModel),
                      const SizedBox(height: 16),

                      // Short description field
                      _buildShortDescriptionField(viewModel),
                      const SizedBox(height: 16),

                      // Category selector
                      _buildCategorySelector(viewModel),
                      const SizedBox(height: 16),

                      // Long description (main content)
                      _buildLongDescriptionField(viewModel),
                      const SizedBox(height: 16),

                      // Image URL (optional)
                      _buildImageUrlField(),
                      const SizedBox(height: 16),

                      // Original source URL (optional)
                      _buildSourceUrlField(),
                      const SizedBox(height: 16),

                      // Author type selector
                      _buildAuthorTypeSelector(viewModel),
                      const SizedBox(height: 16),

                      // Institution (conditional)
                      if (viewModel.authorType != 'citizen')
                        _buildInstitutionField(),
                      if (viewModel.authorType != 'citizen')
                        const SizedBox(height: 24),

                      // Preview button
                      OutlinedButton.icon(
                        onPressed: () => _showPreview(viewModel),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Vista Previa'),
                      ),
                      const SizedBox(height: 16),

                      // Publish button
                      ElevatedButton.icon(
                        onPressed: viewModel.isPublishing || !viewModel.isValid
                            ? null
                            : () => _publish(viewModel),
                        icon: viewModel.isPublishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.publish),
                        label: const Text('Publicar Noticia'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Validation hint
                      if (!viewModel.isValid && viewModel.hasUnsavedChanges)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            viewModel.validationError ?? 'Completa todos los campos requeridos',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBanner({
    required String message,
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isError ? Colors.red.shade100 : Colors.green.shade100,
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade900 : Colors.green.shade900,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
            color: isError ? Colors.red.shade900 : Colors.green.shade900,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(CreateNewsViewModel viewModel) {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Título *',
        hintText: 'Escribe un título llamativo',
        border: const OutlineInputBorder(),
        suffixText: '${viewModel.getCharacterCount('title')}/150',
        suffixIcon: viewModel.meetsMinimumLength('title')
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
      maxLength: 150,
      maxLines: 2,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El título es requerido';
        }
        if (value.length < 10) {
          return 'Mínimo 10 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildShortDescriptionField(CreateNewsViewModel viewModel) {
    return TextFormField(
      controller: _shortDescController,
      decoration: InputDecoration(
        labelText: 'Descripción Corta *',
        hintText: 'Resume tu noticia en pocas palabras',
        border: const OutlineInputBorder(),
        suffixText: '${viewModel.getCharacterCount('shortDescription')}/200',
        suffixIcon: viewModel.meetsMinimumLength('shortDescription')
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        helperText: 'Mínimo 20 caracteres',
      ),
      maxLength: 200,
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'La descripción corta es requerida';
        }
        if (value.length < 20) {
          return 'Mínimo 20 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector(CreateNewsViewModel viewModel) {
    final categories = context.read<CategoriesRepository>().getAllCategories();

    return DropdownButtonFormField<String>(
      value: viewModel.categoryId.isEmpty ? null : viewModel.categoryId,
      decoration: const InputDecoration(
        labelText: 'Categoría *',
        border: OutlineInputBorder(),
      ),
      items: categories.map((category) {
        return DropdownMenuItem(
          value: category.category_id,
          child: Text(category.name),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          viewModel.updateCategory(value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Debes seleccionar una categoría';
        }
        return null;
      },
    );
  }

  Widget _buildLongDescriptionField(CreateNewsViewModel viewModel) {
    return TextFormField(
      controller: _longDescController,
      decoration: InputDecoration(
        labelText: 'Contenido Completo *',
        hintText: 'Escribe el contenido detallado de tu noticia',
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
        suffixText: '${viewModel.getCharacterCount('longDescription')}/5000',
        helperText: 'Mínimo 100 caracteres',
        helperMaxLines: 2,
      ),
      maxLength: 5000,
      maxLines: 10,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El contenido es requerido';
        }
        if (value.length < 100) {
          return 'Mínimo 100 caracteres para el contenido';
        }
        return null;
      },
    );
  }

  Widget _buildImageUrlField() {
    return TextFormField(
      controller: _imageUrlController,
      decoration: const InputDecoration(
        labelText: 'URL de Imagen (opcional)',
        hintText: 'https://example.com/image.jpg',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.image),
      ),
      keyboardType: TextInputType.url,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri == null || !uri.hasScheme) {
            return 'URL inválida';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSourceUrlField() {
    return TextFormField(
      controller: _sourceUrlController,
      decoration: const InputDecoration(
        labelText: 'Fuente Original (opcional)',
        hintText: 'https://fuente-original.com/articulo',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.link),
      ),
      keyboardType: TextInputType.url,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri == null || !uri.hasScheme) {
            return 'URL inválida';
          }
        }
        return null;
      },
    );
  }

  Widget _buildAuthorTypeSelector(CreateNewsViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Autor *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Ciudadano'),
              selected: viewModel.authorType == 'citizen',
              onSelected: (_) => viewModel.updateAuthorType('citizen'),
            ),
            ChoiceChip(
              label: const Text('Periodista'),
              selected: viewModel.authorType == 'journalist',
              onSelected: (_) => viewModel.updateAuthorType('journalist'),
            ),
            ChoiceChip(
              label: const Text('Institución'),
              selected: viewModel.authorType == 'institution',
              onSelected: (_) => viewModel.updateAuthorType('institution'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstitutionField() {
    return TextFormField(
      controller: _institutionController,
      decoration: const InputDecoration(
        labelText: 'Nombre de la Institución *',
        hintText: 'Ej: El Tiempo, CNN, Universidad Nacional',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.business),
      ),
      validator: (value) {
        final viewModel = context.read<CreateNewsViewModel>();
        if (viewModel.authorType != 'citizen' &&
            (value == null || value.trim().isEmpty)) {
          return 'El nombre de la institución es requerido';
        }
        return null;
      },
    );
  }

  Future<void> _saveAsDraft(CreateNewsViewModel viewModel) async {
    final success = await viewModel.saveAsDraft();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador guardado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _publish(CreateNewsViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final confirmed = await _showPublishConfirmDialog();
    if (confirmed != true) return;

    final success = await viewModel.publish();
    if (success && mounted) {
      Navigator.pop(context); // Go back after publishing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Noticia publicada exitosamente!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool?> _showPublishConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar Noticia'),
        content: const Text(
          '¿Estás seguro de que quieres publicar esta noticia? '
          'Una vez publicada, será visible para todos los usuarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  void _showPreview(CreateNewsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista Previa'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.title.isEmpty ? '(Sin título)' : viewModel.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (viewModel.imageUrl != null && viewModel.imageUrl!.isNotEmpty) ...[
                Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image, size: 48),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                viewModel.shortDescription.isEmpty
                    ? '(Sin descripción)'
                    : viewModel.shortDescription,
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Divider(height: 24),
              Text(
                viewModel.longDescription.isEmpty
                    ? '(Sin contenido)'
                    : viewModel.longDescription,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
