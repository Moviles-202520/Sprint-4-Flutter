# Bookmark LWW Conflict Resolution - Test Plan (C.5)

## 📋 Objetivo

Validar que la política **Last-Write-Wins (LWW)** resuelve correctamente conflictos cuando 2 o más dispositivos modifican el mismo bookmark offline y luego reconectan.

---

## 🧪 Test Scenarios

### **Scenario 1: Mismo bookmark agregado en 2 dispositivos (conflicto de creación)**

#### Precondiciones:
- Dispositivo A y B con la misma cuenta
- Ambos sin bookmark para `news_item_id = 123`
- Ambos en modo avión (offline)

#### Pasos:
1. **Dispositivo A** (offline):
   - Agregar bookmark para noticia 123
   - Timestamp local: `2025-11-28 10:00:00`
   
2. **Dispositivo B** (offline):
   - Agregar bookmark para noticia 123
   - Timestamp local: `2025-11-28 10:00:05` (5 segundos después)

3. **Dispositivo A** reconecta primero:
   - Sincroniza su bookmark con servidor
   - Servidor recibe: `updated_at = 2025-11-28 10:00:00`

4. **Dispositivo B** reconecta después:
   - Sincroniza su bookmark
   - Detecta conflicto (ambos tienen `news_item_id = 123`)

#### Resultado Esperado:
- ✅ Servidor mantiene el bookmark de **Dispositivo B** (más reciente: `10:00:05`)
- ✅ Dispositivo A se actualiza al sincronizar de vuelta
- ✅ Ambos dispositivos quedan con `updated_at = 2025-11-28 10:00:05`
- ✅ No hay duplicados en la tabla

#### Verificación:
```dart
// En ambos dispositivos después de sync completo
final bookmarks = await repository.getBookmarks();
final bookmark = bookmarks.firstWhere((b) => b.newsItemId == 123);

assert(bookmark.updatedAt == DateTime(2025, 11, 28, 10, 0, 5));
assert(bookmarks.where((b) => b.newsItemId == 123).length == 1); // Solo uno
```

---

### **Scenario 2: Bookmark eliminado en un dispositivo, modificado en otro**

#### Precondiciones:
- Ambos dispositivos con bookmark para `news_item_id = 456`
- Bookmark existe en servidor: `updated_at = 2025-11-28 09:00:00`
- Ambos en modo avión

#### Pasos:
1. **Dispositivo A** (offline):
   - Eliminar bookmark 456 (soft delete)
   - Timestamp local: `2025-11-28 10:05:00`

2. **Dispositivo B** (offline):
   - Agregar bookmark 456 nuevamente (es un re-add)
   - Timestamp local: `2025-11-28 10:05:10` (10 segundos después)

3. **Ambos dispositivos** reconectan:
   - Sincronización concurrente

#### Resultado Esperado:
- ✅ El bookmark de **Dispositivo B gana** (más reciente: `10:05:10`)
- ✅ `is_deleted = false` (porque B lo agregó, no lo eliminó)
- ✅ Dispositivo A recibe actualización y ve bookmark restaurado

#### Verificación:
```dart
final bookmarks = await repository.getBookmarks(includeDeleted: true);
final bookmark = bookmarks.firstWhere((b) => b.newsItemId == 456);

assert(bookmark.isDeleted == false); // B ganó (no eliminado)
assert(bookmark.updatedAt == DateTime(2025, 11, 28, 10, 5, 10));
```

---

### **Scenario 3: Mismo bookmark eliminado en 2 dispositivos (timestamps diferentes)**

#### Precondiciones:
- Ambos dispositivos con bookmark para `news_item_id = 789`
- Ambos en modo avión

#### Pasos:
1. **Dispositivo A** (offline):
   - Eliminar bookmark 789
   - Timestamp: `2025-11-28 10:10:00`

2. **Dispositivo B** (offline):
   - Eliminar bookmark 789
   - Timestamp: `2025-11-28 10:10:03` (3 segundos después)

3. **Ambos reconectan**

#### Resultado Esperado:
- ✅ Ambos bookmarks marcados como `is_deleted = true`
- ✅ El servidor usa el timestamp **más reciente** (`10:10:03` de Dispositivo B)
- ✅ No hay conflicto efectivo (ambos querían eliminar)

#### Verificación:
```dart
final bookmarks = await repository.getBookmarks(includeDeleted: true);
final bookmark = bookmarks.firstWhere((b) => b.newsItemId == 789);

assert(bookmark.isDeleted == true);
assert(bookmark.updatedAt == DateTime(2025, 11, 28, 10, 10, 3)); // B ganó
```

---

### **Scenario 4: 3 dispositivos con cambios concurrentes (caos controlado)**

#### Precondiciones:
- Dispositivos A, B, C con bookmark para `news_item_id = 999`
- Estado inicial: `updated_at = 2025-11-28 09:00:00`, `is_deleted = false`
- Todos en modo avión

#### Pasos:
1. **Dispositivo A** (offline): Elimina 999 → `10:15:00`
2. **Dispositivo B** (offline): Re-agrega 999 → `10:15:05`
3. **Dispositivo C** (offline): Elimina 999 → `10:15:10` (más reciente)

4. **Todos reconectan** en orden aleatorio

#### Resultado Esperado:
- ✅ **Dispositivo C gana** (timestamp más reciente: `10:15:10`)
- ✅ Estado final: `is_deleted = true` (última operación fue eliminar)
- ✅ Todos los dispositivos convergen al mismo estado

#### Verificación:
```dart
// En cada dispositivo después de sync completo
final bookmarks = await repository.getBookmarks(includeDeleted: true);
final bookmark = bookmarks.firstWhere((b) => b.newsItemId == 999);

assert(bookmark.isDeleted == true); // C ganó (eliminación)
assert(bookmark.updatedAt == DateTime(2025, 11, 28, 10, 15, 10));

// Ejecutar en A, B y C → todos deben pasar
```

---

### **Scenario 5: Verificar idempotencia de upsert**

#### Objetivo:
Validar que llamar `addBookmark()` múltiples veces con el mismo `news_item_id` no crea duplicados.

#### Pasos:
1. Dispositivo A (online):
   ```dart
   await repository.addBookmark(111);
   await repository.addBookmark(111); // Segunda llamada
   await repository.addBookmark(111); // Tercera llamada
   ```

2. Verificar DB local y servidor

#### Resultado Esperado:
- ✅ Solo **1 bookmark** con `news_item_id = 111`
- ✅ `updated_at` se actualiza con cada llamada (más reciente)
- ✅ No hay errores de constraint violation

#### Verificación:
```dart
final bookmarks = await repository.getBookmarks();
final matching = bookmarks.where((b) => b.newsItemId == 111).toList();

assert(matching.length == 1); // Solo uno
```

---

## 🛠️ Tools y Helpers para Testing

### Helper: Simular timestamp antiguo (para pruebas manuales)

```dart
// En BookmarkLocalStorage.addBookmark(), temporalmente:
final now = DateTime(2025, 11, 28, 10, 0, 0); // Timestamp fijo
```

### Helper: Verificar estado de sincronización

```dart
Future<void> debugSyncStatus() async {
  final localStorage = BookmarkLocalStorage();
  final userProfileId = getCurrentUserProfileId();
  
  final pending = await localStorage.getPendingSyncBookmarks(userProfileId);
  print('📤 Pendientes de sync: ${pending.length}');
  
  for (final b in pending) {
    print('  - news_id: ${b.newsItemId}, updated: ${b.updatedAt}, deleted: ${b.isDeleted}');
  }
}
```

### Helper: Forzar sincronización manual

```dart
// En cualquier pantalla con botón de debug
await BookmarkSyncWorker.syncNow();
await Future.delayed(Duration(seconds: 5)); // Esperar worker
await repository.getBookmarks(); // Refrescar desde servidor
```

---

## ✅ Acceptance Criteria (C.5)

- [ ] Scenario 1 pasa: Conflicto de creación resuelto por LWW
- [ ] Scenario 2 pasa: Eliminación vs Modificación → más reciente gana
- [ ] Scenario 3 pasa: Doble eliminación sin conflicto
- [ ] Scenario 4 pasa: 3 dispositivos convergen al mismo estado
- [ ] Scenario 5 pasa: Upsert idempotente (sin duplicados)
- [ ] No hay errores de constraint violation en logs
- [ ] No hay duplicados en tabla `bookmarks` después de sync
- [ ] Todos los dispositivos muestran mismo estado después de sync completo

---

## 📊 Reporting Template

```
Test: Scenario X - [Nombre]
Fecha: [YYYY-MM-DD]
Tester: [Nombre]

Dispositivos usados:
- Dispositivo A: [Modelo / Emulador]
- Dispositivo B: [Modelo / Emulador]

Resultado:
[ ] PASS
[ ] FAIL

Evidencia:
- Screenshot 1: Estado inicial
- Screenshot 2: Después de cambios offline
- Screenshot 3: Después de reconexión
- Screenshot 4: Estado final en ambos dispositivos

Logs relevantes:
```
[Pegar logs de sync worker]
```

Notas:
[Cualquier observación adicional]
```

---

## 🚨 Known Issues / Edge Cases

### Edge Case 1: Reloj del dispositivo incorrecto

**Problema**: Si el reloj de un dispositivo está adelantado, sus cambios siempre ganarán (even si fueron anteriores en tiempo real).

**Mitigación**: 
- Usar timestamps del servidor cuando sea posible
- Documentar que LWW depende de relojes sincronizados
- Considerar usar vector clocks en futuras versiones

### Edge Case 2: Latencia de red alta

**Problema**: Si Device A sincroniza muy tarde, sus cambios pueden perderse incluso si fueron primeros en tiempo real.

**Solución actual**: Esto es esperado en LWW. El timestamp más reciente gana, independientemente del orden de llegada.

### Edge Case 3: Cambio rápido (< 1 segundo)

**Problema**: Si 2 dispositivos cambian el mismo bookmark en menos de 1 segundo, el ganador puede ser impredecible (depende de precisión del timestamp).

**Mitigación**: 
- SQLite timestamps tienen precisión de milisegundos
- Probabilidad de colisión exacta es baja en uso normal

---

## 📚 Referencias

- [SQL Migration: enhance_bookmarks_lww.sql](../sql/2025-11-15_enhance_bookmarks_lww.sql)
- [Bookmark Model with LWW](../lib/domain/models/bookmark.dart)
- [HybridBookmarkRepository](../lib/data/repositories/hybrid_bookmark_repository.dart)
- [Last-Write-Wins Strategy (Wikipedia)](https://en.wikipedia.org/wiki/Eventual_consistency#Conflict_resolution)

---

**Última actualización**: 28 de noviembre de 2025  
**Versión**: 1.0.0  
**Estado**: Ready for QA
