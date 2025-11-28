# Notification Sync Worker - Documentación Técnica

## 📋 Resumen

Sistema de sincronización en background para notificaciones con estrategia **offline-first** y **eventual connectivity**. Implementa exponential backoff para reintentos y manejo robusto de errores.

---

## 🏗️ Arquitectura

### Componentes Principales

1. **NotificationLocalStorage** (`lib/data/services/notification_local_storage.dart`)
   - Base de datos SQLite local para persistencia offline
   - Gestiona cola de sincronización con estado (`sync_status`)
   - Métodos: `saveNotification()`, `markAsReadLocal()`, `getPendingSyncNotifications()`

2. **HybridNotificationRepository** (`lib/data/repositories/hybrid_notification_repository.dart`)
   - Coordina entre local storage y Supabase
   - Implementa patrón local-first (lee local primero, sync en background)
   - Detecta conectividad y dispara sincronización automática

3. **NotificationSyncWorker** (`lib/data/workers/notification_sync_worker.dart`)
   - WorkManager para tareas en background
   - Ejecuta cada 15 minutos o bajo demanda
   - Implementa exponential backoff (2s, 4s, 8s, 16s - max 5 intentos)

4. **NotificationSyncService** (`lib/data/services/notification_sync_service.dart`)
   - Monitorea cambios de conectividad
   - Dispara sincronización cuando vuelve la conexión
   - API para forzar sincronización manual (pull-to-refresh)

---

## 🔄 Flujo de Sincronización

### Escenario 1: Usuario marca notificación como leída (Online)

```
Usuario toca "Marcar leída"
       ↓
HybridRepository.markAsRead()
       ↓
1. Escribe en Local Storage (inmediato)
   sync_status = 'pending'
       ↓
2. Intenta POST a Supabase (si hay conexión)
       ↓
   ✅ Éxito: sync_status = 'synced'
   ❌ Error: Queda en cola para worker
```

### Escenario 2: Usuario marca notificación como leída (Offline)

```
Usuario toca "Marcar leída"
       ↓
HybridRepository.markAsRead()
       ↓
1. Escribe en Local Storage (inmediato)
   sync_status = 'pending'
       ↓
2. Detecta sin conexión → encola
       ↓
3. WorkManager ejecuta tarea periódica (cada 15 min)
       ↓
4. callbackDispatcher() lee cola
       ↓
5. Intenta sincronizar con exponential backoff
       ↓
   ✅ Éxito: sync_status = 'synced'
   ❌ Error: sync_status = 'error' (reintentar en próxima ejecución)
```

### Escenario 3: Vuelve la conexión después de offline

```
Conectividad detectada (WiFi/4G)
       ↓
NotificationSyncService.onConnectivityChanged()
       ↓
NotificationSyncWorker.syncNow() (one-shot task)
       ↓
callbackDispatcher() ejecuta inmediatamente
       ↓
Sincroniza todas las notificaciones pendientes
```

---

## ⚙️ Exponential Backoff

Estrategia para evitar saturar el servidor con reintentos:

| Intento | Delay  | Acción                                  |
|---------|--------|-----------------------------------------|
| 1       | 2s     | Primer intento inmediato                |
| 2       | 4s     | Espera 4 segundos antes de reintentar   |
| 3       | 8s     | Espera 8 segundos antes de reintentar   |
| 4       | 16s    | Espera 16 segundos antes de reintentar  |
| 5       | 16s    | Último intento (cap a 16 segundos)      |
| 6+      | -      | Marca como error permanente             |

```dart
int _calculateBackoffDelay(int attemptCount) {
  if (attemptCount == 0) return 2;
  if (attemptCount == 1) return 4;
  if (attemptCount == 2) return 8;
  return 16; // Cap a 16 segundos
}
```

---

## 📊 Estados de Sincronización

### `sync_status` (campo en `local_notifications`)

- **`synced`**: Notificación sincronizada con servidor
- **`pending`**: Esperando sincronización (en cola)
- **`error`**: Error después de 5 intentos (requiere intervención manual)

### `pending_action` (acción pendiente)

- **`mark_as_read`**: Usuario marcó como leída offline
- **`null`**: Sin acción pendiente

---

## 🔧 Configuración

### Inicialización en `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... inicializar Supabase ...
  
  // Inicializar Sync Worker
  await NotificationSyncWorker.initialize();
  await NotificationSyncWorker.registerPeriodicSync();
  
  runApp(const PuntoNeutroApp());
}
```

### Monitoreo de Conectividad (opcional en App)

```dart
class _MyAppState extends State<MyApp> {
  final _syncService = NotificationSyncService();

  @override
  void initState() {
    super.initState();
    _syncService.startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _syncService.stopConnectivityMonitoring();
    super.dispose();
  }
}
```

### Sincronización Manual (pull-to-refresh)

```dart
Future<void> _handleRefresh() async {
  try {
    await NotificationSyncService().forceSyncNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sincronización completada')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: Sin conexión')),
    );
  }
}
```

---

## 🧪 Testing

### Test Manual - Escenario Offline → Online

1. **Preparación**:
   - Conectar dispositivo a WiFi
   - Login en la app
   - Verificar que hay notificaciones

2. **Probar Offline**:
   - Activar modo avión
   - Marcar 2-3 notificaciones como leídas
   - Verificar en UI que se muestran como leídas
   - Verificar logs: `sync_status = 'pending'`

3. **Probar Reconexión**:
   - Desactivar modo avión
   - Esperar 15-30 segundos (worker ejecuta)
   - Verificar logs: `✅ Sincronizado: <notification_id>`
   - Abrir panel de notificaciones en otro dispositivo
   - Verificar que las notificaciones se muestran como leídas

4. **Verificar Base de Datos**:
   ```dart
   final pending = await NotificationLocalStorage().getPendingSyncNotifications();
   print('Pendientes: ${pending.length}'); // Debe ser 0
   ```

### Test de Exponential Backoff

1. **Simular Error de Servidor**:
   - Modificar temporalmente `SupabaseNotificationRepository.markAsRead()`:
     ```dart
     throw Exception('Simulated server error');
     ```

2. **Marcar como Leída**:
   - Usuario marca notificación como leída
   - Worker intenta sincronizar

3. **Verificar Logs**:
   ```
   ⏳ [Sync Worker] Esperando 2s antes de sincronizar (intento 1/5)
   ❌ [Sync Worker] Error sincronizando: Simulated server error
   ⏳ [Sync Worker] Esperando 4s antes de sincronizar (intento 2/5)
   ❌ [Sync Worker] Error sincronizando: Simulated server error
   ⏳ [Sync Worker] Esperando 8s antes de sincronizar (intento 3/5)
   ```

4. **Verificar Estado Final**:
   - Después de 5 intentos: `sync_status = 'error'`
   - Campo `sync_error` contiene mensaje de error

---

## 📈 Monitoreo y Debugging

### Logs Importantes

- `🔄 [Sync Worker] Iniciando tarea` - Worker ejecutado
- `📤 [Sync Worker] X notificaciones pendientes` - Elementos en cola
- `✅ [Sync Worker] Sincronizado: <id>` - Sincronización exitosa
- `❌ [Sync Worker] Error sincronizando <id>` - Error (revisa `sync_error`)
- `⚠️ [Sync Worker] Límite de reintentos alcanzado` - 5 intentos fallidos

### Queries de Diagnóstico

```dart
// Ver notificaciones pendientes
final pending = await localStorage.getPendingSyncNotifications();
print('Pendientes: ${pending.map((r) => r['notification_id']).toList()}');

// Ver notificaciones con error
final db = await localStorage.database;
final errors = await db.query(
  'local_notifications',
  where: 'sync_status = ?',
  whereArgs: ['error'],
);
print('Con errores: ${errors.length}');

// Limpiar errores (forzar reintento)
await db.update(
  'local_notifications',
  {'sync_status': 'pending', 'sync_error': null},
  where: 'sync_status = ?',
  whereArgs: ['error'],
);
```

---

## 🛠️ Mantenimiento

### Limpiar Notificaciones Antiguas

El worker ejecuta automáticamente cada 30 días:

```dart
await localStorage.cleanOldNotifications(daysToKeep: 30);
```

### Cancelar Worker (en logout)

```dart
await NotificationSyncWorker.cancelAll();
```

### Reiniciar Worker (después de login)

```dart
await NotificationSyncWorker.registerPeriodicSync();
```

---

## 🔐 Seguridad

- **RLS (Row-Level Security)**: Supabase filtra automáticamente por `user_profile_id`
- **Autenticación**: Worker verifica `currentUser` antes de sincronizar
- **Validación**: Local storage valida estructuras antes de guardar
- **Idempotencia**: Sincronizar múltiples veces la misma notificación no causa duplicados

---

## 📦 Dependencias

```yaml
dependencies:
  workmanager: ^0.5.2          # Background tasks
  connectivity_plus: ^5.0.1    # Detectar conectividad
  sqflite: ^2.3.0              # Base de datos local
  supabase_flutter: ^2.1.2     # Backend API
```

---

## 🚀 Deployment

### Android

Agregar permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

### iOS

No requiere configuración adicional (BackgroundFetch se configura automáticamente por WorkManager).

---

## ❓ FAQ

**Q: ¿Qué pasa si el usuario cierra la app?**  
A: WorkManager sigue ejecutando tareas en background (Android). En iOS, las tareas se ejecutan cuando el sistema lo permite.

**Q: ¿Cuánto consume de batería?**  
A: Mínimo. WorkManager usa `Constraints(requiresBatteryNotLow: true)` para no ejecutar con batería baja.

**Q: ¿Qué pasa con notificaciones que fallan 5 veces?**  
A: Quedan con `sync_status = 'error'`. Se pueden reintentar manualmente limpiando el estado o esperando mantenimiento.

**Q: ¿Cómo forzar sincronización desde UI?**  
A: Usar `NotificationSyncService().forceSyncNow()` en un botón o pull-to-refresh.

---

## 📚 Referencias

- [WorkManager Documentation](https://pub.dev/packages/workmanager)
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus)
- [SQLite in Flutter](https://pub.dev/packages/sqflite)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/introduction)

---

**Última actualización**: 28 de noviembre de 2025  
**Versión**: 1.0.0  
**Autor**: Sistema de Sincronización Punto Neutro
