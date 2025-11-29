// =====================================================
// ViewModel: ThemeViewModel
// Purpose: Global theme management for dark/light mode
// Pattern: ChangeNotifier for reactive theme switching
// =====================================================

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _themeBoxName = 'theme_settings';
  static const String _darkModeKey = 'dark_mode';
  
  late Box<dynamic> _themeBox;
  bool _isDarkMode = false;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  ThemeViewModel() {
    _initializeTheme();
  }

  /// Initialize theme from Hive storage
  Future<void> _initializeTheme() async {
    try {
      // Open or get existing box
      if (Hive.isBoxOpen(_themeBoxName)) {
        _themeBox = Hive.box(_themeBoxName);
      } else {
        _themeBox = await Hive.openBox(_themeBoxName);
      }
      
      // Load saved preference
      _isDarkMode = _themeBox.get(_darkModeKey, defaultValue: false) as bool;
      _isInitialized = true;
      
      print('🎨 Theme inicializado: ${_isDarkMode ? "Dark" : "Light"} mode');
      notifyListeners();
    } catch (e) {
      print('⚠️ Error inicializando theme: $e');
      _isDarkMode = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggle between dark and light mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    
    try {
      await _themeBox.put(_darkModeKey, _isDarkMode);
      print('💾 Theme guardado: ${_isDarkMode ? "Dark" : "Light"} mode');
    } catch (e) {
      print('⚠️ Error guardando theme: $e');
    }
    
    notifyListeners();
  }

  /// Set theme explicitly
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    
    _isDarkMode = isDark;
    
    try {
      await _themeBox.put(_darkModeKey, _isDarkMode);
      print('💾 Theme actualizado a: ${_isDarkMode ? "Dark" : "Light"} mode');
    } catch (e) {
      print('⚠️ Error actualizando theme: $e');
    }
    
    notifyListeners();
  }

  /// Sync with user preferences (when loaded from server)
  Future<void> syncWithServerPreferences(bool serverDarkMode) async {
    if (_isDarkMode != serverDarkMode) {
      await setDarkMode(serverDarkMode);
    }
  }

  /// Get appropriate ThemeData based on current mode
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  /// Light theme definition
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: Colors.grey[100],
    colorScheme: ColorScheme.light(
      primary: Colors.indigo,
      secondary: Colors.indigoAccent,
      surface: Colors.white,
      background: Colors.grey[100]!,
      error: Colors.red,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall: TextStyle(color: Colors.black54),
    ),
  );

  /// Dark theme definition
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: Colors.grey[900],
    colorScheme: ColorScheme.dark(
      primary: Colors.indigoAccent,
      secondary: Colors.indigo,
      surface: Colors.grey[850]!,
      background: Colors.grey[900]!,
      error: Colors.redAccent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.grey[850],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white54),
    ),
  );
}
