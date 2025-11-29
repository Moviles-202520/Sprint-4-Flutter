# 🌗 Sistema de Dark Mode - Punto Neutro

## 📋 Descripción

Sistema global de manejo de tema (Dark/Light mode) implementado con persistencia local y sincronización con preferencias del servidor.

## ✨ Características Implementadas

### 1. **ThemeViewModel Global**
- ViewModel centralizado que maneja el estado del tema en toda la app
- Persistencia local usando **Hive** (caja `theme_settings`)
- Sincronización automática con preferencias del servidor
- Notificación reactiva a todos los widgets

### 2. **Persistencia en Múltiples Capas**

#### **Capa Local (Hive)**
- Guarda la preferencia de tema localmente
- Se carga al iniciar la app (antes de cualquier pantalla)
- Funciona offline

#### **Capa Servidor (Supabase)**
- Tabla `user_preferences.dark_mode`
- Sincroniza cuando el usuario cambia la preferencia
- Se carga al entrar a Preferencias

### 3. **Temas Predefinidos**

#### **Light Theme**
```dart
- Background: Colors.grey[100]
- Cards: Colors.white
- Text: Colors.black87
- AppBar: Colors.black (mantiene consistencia visual)
```

#### **Dark Theme**
```dart
- Background: Colors.grey[900]
- Cards: Colors.grey[850]
- Text: Colors.white
- AppBar: Colors.black (consistente con light)
```

## 🔧 Arquitectura

### Flujo de Datos

```
┌─────────────────────────────────────────────────────────┐
│  Usuario cambia modo en Preferencias                    │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  PreferencesViewModel.toggleDarkMode()                  │
│  1. Actualiza user_preferences en Supabase              │
│  2. Llama a ThemeViewModel.setDarkMode()                │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  ThemeViewModel                                         │
│  1. Actualiza _isDarkMode                               │
│  2. Guarda en Hive (persistencia local)                 │
│  3. notifyListeners()                                   │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  MaterialApp (Consumer<ThemeViewModel>)                 │
│  1. Recibe notificación                                 │
│  2. Cambia themeMode                                    │
│  3. Toda la app se re-renderiza con nuevo tema          │
└─────────────────────────────────────────────────────────┘
```

### Inicialización

```
App Start
   ↓
main() → Hive.openBox('theme_settings')
   ↓
PuntoNeutroApp.build()
   ↓
ThemeViewModel created → _initializeTheme()
   ↓
Lee de Hive → _isDarkMode
   ↓
MaterialApp recibe theme/darkTheme/themeMode
   ↓
App renderiza con tema correcto
```

## 📁 Archivos Modificados/Creados

### Nuevos Archivos

1. **`lib/presentation/viewmodels/theme_viewmodel.dart`**
   - ViewModel global de tema
   - Métodos: `toggleTheme()`, `setDarkMode()`, `syncWithServerPreferences()`
   - Propiedades: `isDarkMode`, `isInitialized`, `currentTheme`

### Archivos Modificados

1. **`lib/main.dart`**
   - Agregado: `await Hive.openBox<dynamic>('theme_settings');`
   - Inicializa la caja de theme antes de cargar la app

2. **`lib/presentation/screens/PuntoNeutroApp.dart`**
   - Agregado: `MultiProvider` con `ThemeViewModel`
   - Agregado: `Consumer<ThemeViewModel>` para reactividad
   - Configurado: `theme`, `darkTheme`, `themeMode` en MaterialApp

3. **`lib/presentation/viewmodels/preferences_viewmodel.dart`**
   - Agregado: campo `_themeViewModel`
   - Modificado: `toggleDarkMode()` → llama a `ThemeViewModel.setDarkMode()`
   - Modificado: `loadPreferences()` → sincroniza con ThemeViewModel

4. **`lib/presentation/screens/preferences_screen.dart`**
   - Modificado: Constructor para pasar `ThemeViewModel` al `PreferencesViewModel`

## 🚀 Cómo Usar

### Para el Usuario

1. Abrir la app → **Ajustes** (icono de engranaje en bottom nav)
2. Activar/desactivar el switch **"Modo Oscuro"**
3. El tema cambia **instantáneamente** en toda la app
4. La preferencia se guarda automáticamente

### Para Desarrolladores

#### Obtener Estado Actual del Tema
```dart
final themeViewModel = context.read<ThemeViewModel>();
bool isDark = themeViewModel.isDarkMode;
```

#### Cambiar Tema Programáticamente
```dart
// Toggle
await context.read<ThemeViewModel>().toggleTheme();

// Set explícitamente
await context.read<ThemeViewModel>().setDarkMode(true);
```

#### Sincronizar con Servidor
```dart
// Cuando cargas preferencias del usuario
final serverDarkMode = userPreferences.darkMode;
await themeViewModel.syncWithServerPreferences(serverDarkMode);
```

#### Usar Colores del Tema Actual
```dart
// En cualquier widget
Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
```

## 🎨 Adaptación de Screens Existentes

Las siguientes screens **ya usan Theme.of(context)** y se adaptan automáticamente:

- ✅ **PreferencesScreen**: Cards, text, background
- ✅ **LoginScreen**: Si usa Theme.of(context)
- ✅ **AnalyticsDashboard**: Cards ya tienen `Colors.grey[900]` (dark-friendly)

### Screens que NO cambian (diseñadas como dark-only):

- **NewsFeedScreen**: Fondo negro fijo (TikTok-style)
- **NewsDetailScreen**: Overlay oscuro intencional
- **AppBars**: Negro en ambos temas (consistencia visual)

## 📊 Estados del Sistema

```
┌─────────────────────────────────────────────────────────┐
│  App Initialization                                     │
│  isInitialized = false                                  │
│  Muestra CircularProgressIndicator                      │
└────────────────┬────────────────────────────────────────┘
                 ↓ (Hive carga tema)
┌─────────────────────────────────────────────────────────┐
│  Theme Loaded                                           │
│  isInitialized = true                                   │
│  isDarkMode = true/false (según Hive)                   │
│  Renderiza MaterialApp con tema correcto                │
└─────────────────────────────────────────────────────────┘
                 ↓ (Usuario cambia en Preferencias)
┌─────────────────────────────────────────────────────────┐
│  Theme Changed                                          │
│  1. Actualiza Supabase (user_preferences)               │
│  2. Actualiza Hive (persistencia local)                 │
│  3. notifyListeners() → MaterialApp rebuild             │
└─────────────────────────────────────────────────────────┘
```

## 🔍 Debugging

### Ver Estado del Tema
```dart
print('🎨 Theme: ${themeViewModel.isDarkMode ? "Dark" : "Light"}');
```

### Logs del Sistema
- `🎨 Theme inicializado: Dark/Light mode` - Al cargar desde Hive
- `💾 Theme guardado: Dark/Light mode` - Al cambiar preferencia
- `💾 Theme actualizado a: Dark/Light mode` - Al sincronizar con servidor

### Verificar Hive
```dart
final box = Hive.box('theme_settings');
print('Dark mode en Hive: ${box.get('dark_mode')}');
```

### Verificar Supabase
```sql
SELECT user_profile_id, dark_mode 
FROM user_preferences 
WHERE user_profile_id = YOUR_ID;
```

## ⚠️ Consideraciones

### 1. **Sincronización**
- El tema local (Hive) tiene prioridad al iniciar
- Al cargar preferencias del servidor, se sincroniza automáticamente
- Si hay conflicto, el servidor es la fuente de verdad

### 2. **Performance**
- El cambio de tema causa un rebuild completo de MaterialApp
- Esto es normal y esperado en Flutter
- No causa lag porque los widgets usan Theme.of(context)

### 3. **Compatibilidad Web**
- ✅ Funciona perfectamente (Hive es compatible con web)
- La preferencia persiste en localStorage del navegador

### 4. **Screens Personalizadas**
- Si una screen usa colores hardcoded (ej: `Colors.black`), **no cambiará**
- Usar siempre `Theme.of(context)` para adaptabilidad automática

## 🎯 Testing

### Caso 1: Primera Instalación
1. Instalar app
2. No hay preferencias → Default: **Light mode**
3. Cambiar a Dark → Guarda en Hive + Supabase
4. Cerrar y reabrir app → **Dark mode persiste**

### Caso 2: Usuario con Preferencias Existentes
1. Usuario tiene `dark_mode = true` en Supabase
2. Abrir app → Carga Light de Hive (todavía no sincronizado)
3. Entrar a Preferencias → Se sincroniza con Supabase
4. Tema cambia a Dark automáticamente

### Caso 3: Múltiples Dispositivos
1. Dispositivo A: Activar Dark mode
2. Dispositivo B: Entrar a Preferencias
3. Preferencias se cargan de Supabase → Dark mode activo
4. Tema local se sincroniza

## 📝 Notas Técnicas

- **Hive Box**: `theme_settings` (key: `dark_mode`)
- **Supabase Table**: `user_preferences.dark_mode` (boolean)
- **Pattern**: ChangeNotifier + Consumer para reactividad
- **ThemeMode**: Se calcula dinámicamente según `isDarkMode`

## 🚧 Futuras Mejoras (Opcional)

1. **Tema Automático**: Detectar preferencia del sistema
   ```dart
   ThemeMode.system // Usa preferencia del OS
   ```

2. **Más Temas**: Agregar variantes (AMOLED black, colores personalizados)

3. **Transiciones Animadas**: Animar el cambio de tema
   ```dart
   AnimatedTheme(...)
   ```

4. **Schedule**: Cambio automático según hora del día

---

**Fecha de implementación**: 28 de noviembre de 2025  
**Versión**: 1.0  
**Estado**: ✅ Completamente funcional  
**Compatibilidad**: Web, Android, iOS
