# Migraciones SQL - Punto Neutro

## 📋 Orden de Ejecución

Ejecutar las migraciones en el siguiente orden en Supabase SQL Editor:

1. **`2025-11-28_create_user_preferences.sql`** - Tabla de preferencias de usuario
2. **`2025-11-28_create_user_favorite_categories.sql`** - Categorías favoritas
3. **`2025-11-28_create_notifications.sql`** - Sistema de notificaciones con trigger
4. **`2025-11-28_create_news_read_history.sql`** - Historial de lectura (opcional)
5. **`2025-11-28_alter_news_items_add_search.sql`** - Full-Text Search en news_items
6. **`2025-11-28_alter_bookmarks_add_sync.sql`** - Soporte de sync en bookmarks

---

## 🆕 Tablas Nuevas

### 1. `user_preferences`
Preferencias personales del usuario.

**Columnas:**
- `user_profile_id` (PK, FK → user_profiles)
- `dark_mode` (boolean, default: false)
- `notifications_enabled` (boolean, default: true)
- `language` (text, default: 'es')
- `created_at`, `updated_at` (con trigger automático)

**Características:**
- ✅ RLS: Solo el usuario puede ver/editar sus preferencias
- ✅ Trigger: Actualiza `updated_at` automáticamente

**Uso:**
```sql
-- Obtener preferencias del usuario actual
SELECT * FROM user_preferences 
WHERE user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
);

-- Actualizar dark mode
UPDATE user_preferences 
SET dark_mode = true
WHERE user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
);
```

---

### 2. `user_favorite_categories`
Categorías favoritas para personalizar el feed.

**Columnas:**
- `user_profile_id` (PK compuesta, FK → user_profiles)
- `category_id` (PK compuesta, FK → categories)
- `created_at`

**Características:**
- ✅ PK compuesta: Un usuario no puede marcar la misma categoría dos veces
- ✅ RLS: Solo el usuario puede ver/editar sus favoritos
- ✅ Índices: Por usuario y por categoría

**Uso:**
```sql
-- Agregar categorías favoritas
INSERT INTO user_favorite_categories (user_profile_id, category_id)
VALUES (2, 3), (2, 4); -- Science y Economics

-- Ver categorías favoritas
SELECT ufc.*, c.name AS category_name
FROM user_favorite_categories ufc
JOIN categories c ON ufc.category_id = c.category_id
WHERE ufc.user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
);
```

---

### 3. `notifications`
Sistema de notificaciones reactivo.

**Columnas:**
- `notification_id` (PK, BIGSERIAL)
- `user_profile_id` (FK → user_profiles, receptor)
- `actor_user_profile_id` (FK → user_profiles, quien realizó la acción, nullable)
- `news_item_id` (FK → news_items, nullable)
- `type` (enum: rating_received, comment_received, article_published, system)
- `payload` (JSONB, datos adicionales)
- `is_read` (boolean, default: false)
- `created_at`

**Características:**
- ✅ RLS: Solo el usuario puede ver/actualizar sus notificaciones
- ✅ Trigger automático: Se crea notificación cuando `engagement_events` tiene `action='completed'`
- ✅ Índice compuesto: (user_profile_id, is_read, created_at DESC) para queries rápidas

**Trigger:**
- Cuando se inserta un `engagement_event` con `action='completed'`:
  - Si es `rating` → Notifica al autor con `rating_received`
  - Si es `comment` → Notifica al autor con `comment_received`
  - No notifica si el usuario interactúa con su propia noticia

**Uso:**
```sql
-- Ver notificaciones no leídas
SELECT 
    n.*,
    actor.user_auth_email as actor_email,
    ni.title as news_title
FROM notifications n
LEFT JOIN user_profiles actor ON n.actor_user_profile_id = actor.user_profile_id
LEFT JOIN news_items ni ON n.news_item_id = ni.news_item_id
WHERE n.user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
)
AND n.is_read = false
ORDER BY n.created_at DESC;

-- Marcar como leída
UPDATE notifications
SET is_read = true
WHERE notification_id = 1;

-- Marcar todas como leídas
UPDATE notifications
SET is_read = true
WHERE user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
)
AND is_read = false;
```

---

### 4. `news_read_history` (Opcional)
Historial de lectura para analítica y sync opcional.

**Columnas:**
- `read_id` (PK, BIGSERIAL)
- `user_profile_id` (FK → user_profiles)
- `news_item_id` (FK → news_items)
- `category_id` (FK → categories, nullable)
- `started_at`, `ended_at` (timestamptz)
- `duration_seconds` (integer)
- `created_at`

**Características:**
- ✅ RLS: Solo el usuario puede ver/editar su historial
- ✅ Índices: Por (user, date), por news_item, por category
- ✅ Base 100% local, sync opcional

**Uso:**
```sql
-- Registrar lectura
INSERT INTO news_read_history (user_profile_id, news_item_id, category_id, started_at, ended_at, duration_seconds)
VALUES (2, 1, 3, NOW() - INTERVAL '5 minutes', NOW(), 300);

-- Ver historial reciente
SELECT 
    nrh.*,
    ni.title as news_title,
    c.name as category_name
FROM news_read_history nrh
JOIN news_items ni ON nrh.news_item_id = ni.news_item_id
LEFT JOIN categories c ON nrh.category_id = c.category_id
WHERE nrh.user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
)
ORDER BY nrh.created_at DESC
LIMIT 20;
```

---

## 🔧 Tablas Modificadas

### 5. `news_items` - Full-Text Search

**Nuevas Columnas:**
- `search_vector` (tsvector, GENERATED ALWAYS, español)
  - Generado desde: title + short_description + long_description
- `source_domain` (text, GENERATED ALWAYS)
  - Extraído desde: original_source_url (ej: "www.nasa.gov")

**Nuevos Índices:**
- GIN index en `search_vector` (para búsqueda rápida)
- B-tree index en `LOWER(title)` (para autocomplete)
- Index en `source_domain` (para filtrar por fuente)
- Composite index en `(category_id, publication_date DESC)`

**Funciones Helper:**
- `search_news_items(query, category, limit, offset)` - Búsqueda con ranking
- `get_title_suggestions(prefix, limit)` - Autocomplete de títulos

**Uso:**
```sql
-- Búsqueda full-text
SELECT * FROM search_news_items('NASA Europa vida', NULL, 10, 0);

-- Búsqueda con filtro de categoría
SELECT * FROM search_news_items('economía inflación', 4, 10, 0);

-- Autocomplete de títulos
SELECT * FROM get_title_suggestions('NASA', 5);

-- Agrupar por fuente
SELECT 
    source_domain,
    COUNT(*) as article_count,
    AVG(average_reliability_score) as avg_reliability
FROM news_items
WHERE source_domain IS NOT NULL
GROUP BY source_domain
ORDER BY article_count DESC;
```

---

### 6. `bookmarks` - Soporte de Sync

**Nuevas Columnas:**
- `updated_at` (timestamptz, con trigger automático)
- `is_deleted` (boolean, default: false) - Para soft delete

**Nuevos Índices:**
- UNIQUE index en `(user_profile_id, news_item_id)` - Previene duplicados
- Index en `(user_profile_id, updated_at DESC)` - Para sync
- Partial index en `(user_profile_id, created_at DESC) WHERE is_deleted = false`

**Funciones Helper:**
- `get_bookmarks_since(timestamp, user_id)` - Para pull sync
- `upsert_bookmark_lww(user_id, news_id, is_deleted, updated_at)` - Para push sync con LWW

**Características:**
- ✅ RLS: Solo el usuario puede ver/editar sus bookmarks
- ✅ Trigger: Actualiza `updated_at` automáticamente
- ✅ Last-Write-Wins (LWW): El timestamp más reciente gana en conflictos

**Uso:**
```sql
-- Ver bookmarks activos (no eliminados)
SELECT 
    b.*,
    ni.title as news_title
FROM bookmarks b
JOIN news_items ni ON b.news_item_id = ni.news_item_id
WHERE b.user_profile_id IN (
    SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
)
AND b.is_deleted = false
ORDER BY b.created_at DESC;

-- Soft delete (para sync)
UPDATE bookmarks
SET is_deleted = true
WHERE bookmark_id = 8;

-- Sync pull: Obtener cambios desde última sync
SELECT * FROM get_bookmarks_since('2025-11-01 00:00:00+00', 2);

-- Sync push: Upsert con LWW
SELECT * FROM upsert_bookmark_lww(2, 3, false, NOW());
```

---

## 🔄 Patrón de Sincronización (LWW)

### Last-Write-Wins (LWW) para Bookmarks

**Flujo de Sync:**

1. **Cliente mantiene** `last_sync_timestamp` localmente
2. **Pull changes:**
   ```sql
   SELECT * FROM get_bookmarks_since(last_sync_timestamp, user_id);
   ```
3. **Cliente aplica cambios** localmente con LWW
4. **Push changes:**
   ```sql
   SELECT * FROM upsert_bookmark_lww(user_id, news_id, is_deleted, updated_at);
   ```
5. **Servidor resuelve conflictos** con LWW (timestamp más reciente gana)
6. **Cliente actualiza** `last_sync_timestamp = NOW()`

**Ejemplo de conflicto:**
- Dispositivo A: Marca bookmark como deleted a las 10:00
- Dispositivo B: Marca mismo bookmark como not-deleted a las 10:05
- Resultado: Bookmark queda como not-deleted (10:05 > 10:00)

---

## 📊 Respuestas a Business Questions

### BQ1: ¿Puede el usuario hacer su experiencia más cómoda?
✅ **Sí**
- `user_preferences.dark_mode` - Modo oscuro
- `user_preferences.language` - Idioma preferido
- `user_preferences.notifications_enabled` - Control de notificaciones

### BQ2: ¿Puede aportar a la comunidad con noticias o contenido?
✅ **Sí**
- `news_items` ya registra `user_profile_id` como autor
- Métricas: `engagement_events`, `rating_items`, `comments`

### BQ3: ¿Se puede personalizar el contenido que recibe?
✅ **Sí**
- `user_favorite_categories` - Prioriza feed por categorías favoritas
- El cliente puede filtrar por `category_id IN (SELECT category_id FROM user_favorite_categories...)`

### BQ4: ¿Es consciente de sus acciones para evaluar su conducta?
✅ **Sí**
- `engagement_events` - Todas las interacciones
- `rating_items` - Ratings asignados
- `comments` - Comentarios escritos
- `news_read_history` - Historial de lecturas con duración

**Ejemplo - Estadísticas del usuario:**
```sql
-- Total de interacciones del usuario
SELECT 
    COUNT(DISTINCT CASE WHEN event_type = 'rating' THEN event_id END) as total_ratings,
    COUNT(DISTINCT CASE WHEN event_type = 'comment' THEN event_id END) as total_comments
FROM engagement_events
WHERE user_profile_id = 2;

-- Tiempo total de lectura
SELECT 
    COUNT(*) as articles_read,
    SUM(duration_seconds) as total_seconds,
    AVG(duration_seconds) as avg_seconds_per_article
FROM news_read_history
WHERE user_profile_id = 2;
```

### BQ5: ¿Cuál es la fuente o periódico con menor conformidad por categoría?
✅ **Sí**
- `news_items.source_domain` - Dominio extraído automáticamente
- `rating_items.assigned_reliability_score` - Puntuación de confiabilidad

**Query ejemplo:**
```sql
-- Fuentes con menor confiabilidad por categoría
SELECT 
    c.name as category_name,
    ni.source_domain,
    COUNT(ri.rating_item_id) as total_ratings,
    AVG(ri.assigned_reliability_score) as avg_reliability,
    STDDEV(ri.assigned_reliability_score) as reliability_stddev
FROM news_items ni
JOIN categories c ON ni.category_id = c.category_id
LEFT JOIN rating_items ri ON ni.news_item_id = ri.news_item_id
WHERE ni.source_domain IS NOT NULL
  AND ri.assigned_reliability_score IS NOT NULL
GROUP BY c.category_id, c.name, ni.source_domain
HAVING COUNT(ri.rating_item_id) >= 5  -- Mínimo 5 ratings
ORDER BY c.category_id, avg_reliability ASC;
```

---

## 🛡️ Seguridad (RLS)

Todas las tablas nuevas y modificadas tienen **Row Level Security (RLS)** habilitado:

### Patrón "Self-Access"
```sql
-- El usuario solo accede a sus propios datos
WHERE user_profile_id IN (
    SELECT user_profile_id 
    FROM user_profiles 
    WHERE user_auth_id = auth.uid()
)
```

### Tablas con RLS:
- ✅ `user_preferences` - Self-access completo (SELECT, INSERT, UPDATE, DELETE)
- ✅ `user_favorite_categories` - Self-access (SELECT, INSERT, DELETE)
- ✅ `notifications` - Self-access (SELECT, UPDATE)
- ✅ `news_read_history` - Self-access completo
- ✅ `bookmarks` - Self-access completo

---

## 🎯 Soporte a Funcionalidades

### 🔔 Campana de Notificaciones (Milestone B)
- Tabla: `notifications`
- Trigger: Automático desde `engagement_events`
- Cliente: Sincroniza y marca `is_read = true`

### 📌 Bookmarks con Sync (Milestone C)
- Tabla: `bookmarks` (con `updated_at`, `is_deleted`)
- Patrón: LWW (Last-Write-Wins)
- Funciones: `get_bookmarks_since()`, `upsert_bookmark_lww()`

### 📖 Historial de Lectura (Milestone D)
- Tabla: `news_read_history` (opcional para sync)
- Base: 100% local
- Sync: Opt-in si se desea analítica

### ✏️ Create News (Milestone E)
- Tabla: `news_items` (ya existente, con autor)
- Drafts: 100% locales (SQLite)
- Upload: Queue local + eventual sync

### 🔍 Buscador (Milestone F)
- Columna: `search_vector` (tsvector, GIN index)
- Funciones: `search_news_items()`, `get_title_suggestions()`
- Cliente: Cache local con TTL

---

## 🎨 Soporte a Vistas (Milestone G)

### G.1: Preferencias de Usuario
- `user_preferences` (dark_mode, language, notifications_enabled)
- `user_favorite_categories` (prioriza feed)

### G.2: Notificaciones
- `notifications` (con paginación por is_read, created_at)

### G.3: Bookmarks e Historial
- `bookmarks` (con sync LWW)
- `news_read_history` (opcional)

### G.4: Create News
- `news_items` (registra autor en user_profile_id)

### G.5: Buscador
- `search_news_items()` + `get_title_suggestions()`
- Cliente: Cache con TTL

---

## ⚡ Optimizaciones

### Índices Clave:
- **GIN index** en `news_items.search_vector` - Búsqueda full-text <100ms
- **Composite index** en `notifications(user_profile_id, is_read, created_at DESC)` - Queries rápidas
- **UNIQUE index** en `bookmarks(user_profile_id, news_item_id)` - Previene duplicados
- **B-tree index** en `news_items(LOWER(title))` - Autocomplete rápido

### Columnas Generadas:
- `search_vector` - Auto-actualizada en INSERT/UPDATE
- `source_domain` - Extraída automáticamente desde URL

### Triggers:
- `set_updated_at()` - Actualiza timestamps automáticamente
- `create_notification_from_engagement()` - Notificaciones reactivas

---

## 🧹 Mantenimiento

### Limpieza periódica de bookmarks eliminados:
```sql
-- Eliminar bookmarks soft-deleted hace más de 30 días
DELETE FROM bookmarks
WHERE is_deleted = true 
  AND updated_at < NOW() - INTERVAL '30 days';
```

### Limpieza de notificaciones antiguas leídas:
```sql
-- Eliminar notificaciones leídas hace más de 90 días
DELETE FROM notifications
WHERE is_read = true 
  AND created_at < NOW() - INTERVAL '90 days';
```

---

## 📝 Notas Técnicas

### Columnas Generadas (GENERATED ALWAYS):
- Se actualizan automáticamente en INSERT/UPDATE
- No se pueden modificar manualmente
- Ideales para índices derivados (search_vector, source_domain)

### JSONB vs JSON:
- Usamos `JSONB` en `notifications.payload`
- Más eficiente para queries, soporta índices
- Permite extraer campos: `payload->>'rating_score'`

### SECURITY DEFINER:
- Funciones `get_bookmarks_since()` y `upsert_bookmark_lww()` usan SECURITY DEFINER
- Ejecutan con permisos del owner, no del caller
- Necesario para cross-user queries en sync

---

## ✅ Checklist Post-Migración

Después de ejecutar todas las migraciones, verificar:

- [ ] Todas las tablas creadas: `\dt` en psql
- [ ] Todos los índices creados: `\di` en psql
- [ ] RLS habilitado: `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';`
- [ ] Triggers funcionando: Insertar un engagement_event y verificar notification
- [ ] Full-Text Search: Ejecutar `search_news_items('test', NULL, 10, 0)`
- [ ] Sync bookmarks: Ejecutar `get_bookmarks_since(NOW() - INTERVAL '1 day', <user_id>)`

---

## 🔄 Rollback

Cada archivo SQL incluye un bloque comentado de **ROLLBACK** al final. Para deshacer una migración:

1. Copiar el bloque ROLLBACK del archivo
2. Descomentar las líneas
3. Ejecutar en Supabase SQL Editor
4. Verificar que las tablas/índices fueron eliminados

**Orden de rollback** (inverso a la ejecución):
1. `2025-11-28_alter_bookmarks_add_sync.sql`
2. `2025-11-28_alter_news_items_add_search.sql`
3. `2025-11-28_create_news_read_history.sql`
4. `2025-11-28_create_notifications.sql`
5. `2025-11-28_create_user_favorite_categories.sql`
6. `2025-11-28_create_user_preferences.sql`

---

## 📚 Referencias

- [Supabase Full-Text Search](https://supabase.com/docs/guides/database/full-text-search)
- [PostgreSQL tsvector](https://www.postgresql.org/docs/current/datatype-textsearch.html)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)
- [JSONB Type](https://www.postgresql.org/docs/current/datatype-json.html)

---

**Autor:** Copilot  
**Fecha:** 2025-11-28  
**Proyecto:** Punto Neutro - Sprint 4
