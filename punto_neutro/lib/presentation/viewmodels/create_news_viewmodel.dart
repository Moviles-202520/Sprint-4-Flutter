// =====================================================
// ViewModel: Create/Edit News
// Purpose: Manage news creation and editing state
// Features: Validation, draft saving, publishing, preview
// =====================================================

import 'dart:async'; // 👈 NUEVO para Timer
import 'package:flutter/foundation.dart';
import '../../domain/models/news_creation_data.dart';
import '../../domain/repositories/news_repository.dart';

class CreateNewsViewModel extends ChangeNotifier {
  final NewsRepository _repository;
  final String _userProfileId;

  CreateNewsViewModel({
    required NewsRepository repository,
    required String userProfileId,
  })  : _repository = repository,
        _userProfileId = userProfileId;

  // State
  NewsCreationData _data = NewsCreationData.empty();
  bool _isSaving = false;
  bool _isPublishing = false;
  String? _error;
  String? _successMessage;

  // 🔁 Estado para AUTOSAVE con throttle
  Timer? _autosaveTimer;
  static const Duration _autosaveDelay = Duration(seconds: 2);
  String _lastAutosavedTitle = '';
  String _lastAutosavedShortDescription = '';
  String _lastAutosavedLongDescription = '';

  // Getters
  NewsCreationData get data => _data;
  bool get isSaving => _isSaving;
  bool get isPublishing => _isPublishing;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isValid => _data.isValid;
  String? get validationError => _data.validationError;
  bool get hasUnsavedChanges =>
      _data.title.isNotEmpty ||
          _data.shortDescription.isNotEmpty ||
          _data.longDescription.isNotEmpty;

  // Campos individuales
  String get title => _data.title;
  String get shortDescription => _data.shortDescription;
  String get longDescription => _data.longDescription;
  String get categoryId => _data.categoryId;
  String? get imageUrl => _data.imageUrl;
  String? get originalSourceUrl => _data.originalSourceUrl;
  String get authorType => _data.authorType;
  String get authorInstitution => _data.authorInstitution;

  // -------------------------------------------------
  // Helpers internos de autosave
  // -------------------------------------------------

  bool get _hasChangesSinceLastAutosave =>
      _data.title != _lastAutosavedTitle ||
          _data.shortDescription != _lastAutosavedShortDescription ||
          _data.longDescription != _lastAutosavedLongDescription;

  void _scheduleAutosaveIfNeeded() {
    // Cancelar cualquier timer previo
    _autosaveTimer?.cancel();

    // Si no hay cambios significativos, no hacemos nada
    if (!hasUnsavedChanges || !_hasChangesSinceLastAutosave) {
      return;
    }

    // Programar autosave en X segundos
    _autosaveTimer = Timer(_autosaveDelay, () {
      _performAutosave();
    });
  }

  Future<void> _performAutosave() async {
    // Evitar solapar con un guardado manual
    if (_isSaving) return;
    if (!hasUnsavedChanges || !_hasChangesSinceLastAutosave) return;

    final success = await saveAsDraft();
    if (success) {
      _lastAutosavedTitle = _data.title;
      _lastAutosavedShortDescription = _data.shortDescription;
      _lastAutosavedLongDescription = _data.longDescription;
    }
  }

  // -------------------------------------------------
  // Actualización de campos (ahora con autosave)
  // -------------------------------------------------

  /// Update title
  void updateTitle(String value) {
    _data = _data.copyWith(title: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded(); // 👈 NUEVO
    notifyListeners();
  }

  /// Update short description
  void updateShortDescription(String value) {
    _data = _data.copyWith(shortDescription: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded(); // 👈 NUEVO
    notifyListeners();
  }

  /// Update long description (main content)
  void updateLongDescription(String value) {
    _data = _data.copyWith(longDescription: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded(); // 👈 NUEVO
    notifyListeners();
  }

  /// Update category
  void updateCategory(String value) {
    _data = _data.copyWith(categoryId: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded(); // opcional, pero útil si cambia mucho
    notifyListeners();
  }

  /// Update image URL
  void updateImageUrl(String? value) {
    _data = _data.copyWith(imageUrl: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded();
    notifyListeners();
  }

  /// Update original source URL
  void updateOriginalSourceUrl(String? value) {
    _data = _data.copyWith(originalSourceUrl: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded();
    notifyListeners();
  }

  /// Update author type
  void updateAuthorType(String value) {
    _data = _data.copyWith(authorType: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded();
    notifyListeners();
  }

  /// Update author institution
  void updateAuthorInstitution(String value) {
    _data = _data.copyWith(authorInstitution: value);
    _clearMessages();
    _scheduleAutosaveIfNeeded();
    notifyListeners();
  }

  // -------------------------------------------------
  // Acciones principales: guardar borrador / publicar
  // -------------------------------------------------

  /// Save as draft (no validation required)
  Future<bool> saveAsDraft() async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Save as draft to repository
      await _repository.createNewsArticle(
        title: _data.title.isEmpty ? 'Borrador sin título' : _data.title,
        shortDescription:
        _data.shortDescription.isEmpty ? 'Borrador' : _data.shortDescription,
        longDescription: _data.longDescription.isEmpty
            ? 'Borrador en progreso'
            : _data.longDescription,
        categoryId: _data.categoryId.isEmpty ? '1' : _data.categoryId,
        authorId: _userProfileId,
        authorType: _data.authorType,
        authorInstitution: _data.authorInstitution,
        imageUrl: _data.imageUrl,
        originalSourceUrl: _data.originalSourceUrl,
        isDraft: true,
      );

      _successMessage = 'Borrador guardado exitosamente';
      _isSaving = false;

      // Actualizar baseline de autosave
      _lastAutosavedTitle = _data.title;
      _lastAutosavedShortDescription = _data.shortDescription;
      _lastAutosavedLongDescription = _data.longDescription;

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al guardar borrador: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Publish news (requires full validation)
  Future<bool> publish() async {
    if (_isPublishing) return false;

    // Validate before publishing
    if (!_data.isValid) {
      _error = _data.validationError ?? 'Formulario inválido';
      notifyListeners();
      return false;
    }

    _isPublishing = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Set publication date and mark as published
      _data = _data.copyWith(
        isDraft: false,
        publicationDate: DateTime.now(),
      );

      // Publish to repository
      await _repository.createNewsArticle(
        title: _data.title,
        shortDescription: _data.shortDescription,
        longDescription: _data.longDescription,
        categoryId: _data.categoryId,
        authorId: _userProfileId,
        authorType: _data.authorType,
        authorInstitution: _data.authorInstitution,
        imageUrl: _data.imageUrl,
        originalSourceUrl: _data.originalSourceUrl,
        isDraft: false,
      );

      _successMessage = '¡Noticia publicada exitosamente!';
      _isPublishing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al publicar noticia: $e';
      _isPublishing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear form (reset to empty)
  void clearForm() {
    _data = NewsCreationData.empty();
    _clearMessages();

    // Resetear estado de autosave
    _autosaveTimer?.cancel();
    _lastAutosavedTitle = '';
    _lastAutosavedShortDescription = '';
    _lastAutosavedLongDescription = '';

    notifyListeners();
  }

  /// Load existing news for editing
  Future<void> loadNewsForEditing(String newsItemId) async {
    try {
      // TODO: Implement loading existing news from repository
      // For now, just reset form
      _data = NewsCreationData.empty();
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar noticia: $e';
      notifyListeners();
    }
  }

  /// Clear error and success messages
  void _clearMessages() {
    if (_error != null || _successMessage != null) {
      _error = null;
      _successMessage = null;
    }
  }

  /// Clear error message explicitly
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear success message explicitly
  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  /// Get character count for field
  int getCharacterCount(String field) {
    switch (field) {
      case 'title':
        return _data.title.length;
      case 'shortDescription':
        return _data.shortDescription.length;
      case 'longDescription':
        return _data.longDescription.length;
      default:
        return 0;
    }
  }

  /// Check if field meets minimum length
  bool meetsMinimumLength(String field) {
    switch (field) {
      case 'title':
        return _data.title.length >= 10;
      case 'shortDescription':
        return _data.shortDescription.length >= 20;
      case 'longDescription':
        return _data.longDescription.length >= 100;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
