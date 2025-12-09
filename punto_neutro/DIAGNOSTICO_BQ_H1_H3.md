# 🔧 Business Questions H.1 y H.3 - Diagnóstico y Solución

## 📋 Resumen del Problema

**BQ H.1 - Dark Mode Adoption:** Muestra 0.0%
**BQ H.3 - Personalization Effectiveness:** Muestra 0.0% (6 impresiones totales, 0 en favoritos)

---

## 🔍 Análisis del Problema

### **H.1: Dark Mode Adoption - Función SQL Faltante**

**Ubicación del código:**
- `lib/view_models/analytics_dashboard_viewmodel.dart` línea 456

**Código actual:**
```dart
Future<void> loadBQH1DarkModeUsage() async {
  try {
    final result = await _supabase.rpc('get_dark_mode_percentage');
    _bqH1DarkModeData = {
      'dark_mode_percentage': result ?? 0.0,
      'total_users': 0,
    };
    notifyListeners();
  } catch (e) {
    print('❌ Error loading BQ H.1: $e');
    _bqH1DarkModeData = {'error': e.toString()};
  }
}
```

**Problema identificado:**
- ❌ La función RPC `get_dark_mode_percentage` **NO EXISTE** en tu base de datos Supabase
- El código intenta llamarla pero falla silenciosamente, retornando 0.0

**Solución:**
✅ He creado el archivo SQL `sql/2025-11-29_create_analytics_functions.sql` con la función necesaria.

**Debes ejecutar este SQL en Supabase:**
```sql
CREATE OR REPLACE FUNCTION get_dark_mode_percentage()
RETURNS NUMERIC AS $$
DECLARE
    total_users INT;
    dark_mode_users INT;
    percentage NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_users FROM user_preferences;
    
    IF total_users = 0 THEN
        RETURN 0.0;
    END IF;
    
    SELECT COUNT(*) INTO dark_mode_users 
    FROM user_preferences 
    WHERE dark_mode = true;
    
    percentage := (dark_mode_users::NUMERIC / total_users::NUMERIC) * 100.0;
    
    RETURN ROUND(percentage, 2);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_dark_mode_percentage() TO authenticated;
```

**Cómo ejecutar:**
1. Abre Supabase Dashboard → SQL Editor
2. Copia y pega el contenido de `sql/2025-11-29_create_analytics_functions.sql`
3. Ejecuta el script
4. Verifica con: `SELECT get_dark_mode_percentage();`

---

### **H.3: Personalization Effectiveness - Sin Categorías Favoritas**

**Ubicación del código:**
- `lib/view_models/analytics_dashboard_viewmodel.dart` líneas 508-562

**Código actual:**
```dart
Future<void> loadBQH3Personalization() async {
  try {
    // Get user's favorite categories
    final favorites = await _supabase
        .from('user_favorite_categories')
        .select('category_id')
        .eq('user_profile_id', userProfileId);

    final favCategoryIds = favorites.map((f) => f['category_id'] as int).toList();

    // Get user's session impressions
    final sessions = await _supabase
        .from('user_sessions')
        .select('user_session_id')
        .eq('user_profile_id', userProfileId)
        .limit(10);

    int totalImpressions = 0;
    int favoriteImpressions = 0;

    for (var session in sessions) {
      final viewed = await _supabase
          .from('viewed_categories')
          .select('category_id')
          .eq('user_session_id', session['user_session_id']);

      totalImpressions += viewed.length;
      favoriteImpressions += viewed.where((v) => favCategoryIds.contains(v['category_id'])).length;
    }

    final personalizationRatio = totalImpressions > 0
        ? (favoriteImpressions / totalImpressions) * 100
        : 0.0;

    _bqH3PersonalizationData = {
      'personalization_ratio': personalizationRatio,
      'total_impressions': totalImpressions,
      'favorite_impressions': favoriteImpressions,
    };
  }
}
```

**Problema identificado:**
Según el screenshot, la BQ H.3 muestra:
- ✅ Total impresiones: **6** → `user_sessions` tiene datos
- ❌ En favoritos: **0** → Indica dos posibles problemas:

**Opción 1:** La tabla `user_favorite_categories` está **vacía**
- El usuario nunca ha seleccionado categorías favoritas
- Por lo tanto, `favCategoryIds` es una lista vacía `[]`
- Ninguna impresión puede coincidir con categorías favoritas

**Opción 2:** La tabla `viewed_categories` está **vacía**
- Las sesiones existen pero no tienen categorías registradas
- `totalImpressions` debería ser 0 pero muestra 6
- Esto sugiere que el problema es la Opción 1

**Causa raíz:** 
No hay datos en `user_favorite_categories` para el usuario actual.

**Soluciones posibles:**

**A) Solución rápida - Agregar datos de prueba:**
```sql
-- Ejecutar en Supabase SQL Editor
-- Reemplaza 1 con el user_profile_id del usuario actual

-- Insertar categorías favoritas de prueba (IDs 1, 3, 5 son ejemplos)
INSERT INTO user_favorite_categories (user_profile_id, category_id)
VALUES 
  (1, 1),
  (1, 3),
  (1, 5)
ON CONFLICT (user_profile_id, category_id) DO NOTHING;
```

**B) Solución a largo plazo - Mejorar la UI:**
Si el usuario no ha seleccionado categorías favoritas, la UI debería mostrar un mensaje más claro:

```dart
// En analytics_dashboard_screen.dart
Text(
  favCategoryIds.isEmpty 
    ? 'No has seleccionado categorías favoritas aún'
    : '${data['personalization_ratio'].toStringAsFixed(1)}% Personalizado'
)
```

**C) Verificar que la feature de favoritos está implementada:**
¿Existe una pantalla donde el usuario pueda seleccionar categorías favoritas?
- Si NO existe → Debes implementarla primero
- Si existe → Verificar que guarda correctamente en `user_favorite_categories`

---

## 🧪 Verificación del Estado de la Base de Datos

**Ejecuta estas queries en Supabase SQL Editor para diagnosticar:**

```sql
-- 1. Verificar tabla user_preferences
SELECT 
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE dark_mode = true) as dark_mode_users,
    ROUND((COUNT(*) FILTER (WHERE dark_mode = true)::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100, 2) as percentage
FROM user_preferences;

-- 2. Verificar user_favorite_categories
SELECT 
    user_profile_id,
    COUNT(*) as favorite_count
FROM user_favorite_categories
GROUP BY user_profile_id;

-- 3. Verificar user_sessions
SELECT 
    COUNT(*) as total_sessions,
    COUNT(DISTINCT user_profile_id) as unique_users
FROM user_sessions;

-- 4. Verificar viewed_categories
SELECT 
    COUNT(*) as total_viewed,
    COUNT(DISTINCT user_session_id) as sessions_with_views,
    COUNT(DISTINCT category_id) as unique_categories
FROM viewed_categories;
```

**Resultados esperados:**

| Tabla | Estado Esperado | Si está vacío |
|-------|----------------|---------------|
| `user_preferences` | Debería tener al menos 1 row por usuario | ❌ H.1 mostrará 0.0% |
| `user_favorite_categories` | Debería tener categorías seleccionadas | ❌ H.3 mostrará 0% |
| `user_sessions` | Tiene 6 registros ✅ | - |
| `viewed_categories` | Debería tener registros de vistas | ⚠️ H.3 no contará impresiones correctamente |

---

## ✅ Pasos para Resolver

### **Para H.1 (Dark Mode Adoption):**

1. **Ejecutar el script SQL:**
   ```bash
   # En Supabase Dashboard > SQL Editor
   # Copia el contenido de sql/2025-11-29_create_analytics_functions.sql
   # Ejecuta el script completo
   ```

2. **Verificar la función:**
   ```sql
   SELECT get_dark_mode_percentage();
   ```

3. **Asegurar que hay datos en user_preferences:**
   ```sql
   -- Insertar preferencia de prueba para el usuario actual
   INSERT INTO user_preferences (user_profile_id, dark_mode)
   SELECT user_profile_id, true 
   FROM user_profiles 
   WHERE user_auth_id = auth.uid()
   ON CONFLICT (user_profile_id) 
   DO UPDATE SET dark_mode = true;
   ```

4. **Recargar el dashboard en Flutter:**
   - La BQ H.1 ahora debería mostrar el porcentaje real

### **Para H.3 (Personalization Effectiveness):**

1. **Verificar si hay categorías favoritas:**
   ```sql
   SELECT * FROM user_favorite_categories 
   WHERE user_profile_id IN (
     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
   );
   ```

2. **Si está vacío, agregar datos de prueba:**
   ```sql
   -- Reemplaza 1 con el user_profile_id correcto
   INSERT INTO user_favorite_categories (user_profile_id, category_id)
   SELECT 1, category_id FROM categories LIMIT 3
   ON CONFLICT DO NOTHING;
   ```

3. **Verificar viewed_categories tiene datos:**
   ```sql
   SELECT vs.user_session_id, COUNT(vc.category_id) as viewed_count
   FROM user_sessions vs
   LEFT JOIN viewed_categories vc ON vs.user_session_id = vc.user_session_id
   GROUP BY vs.user_session_id;
   ```

4. **Si viewed_categories está vacío:**
   - El sistema no está registrando qué categorías ve el usuario
   - Necesitas implementar el tracking de vistas en el código Flutter
   - Busca dónde se registran las sesiones y agrega inserts a `viewed_categories`

5. **Alternativa - Cambiar lógica de H.3:**
   Si `viewed_categories` no se está usando, podrías cambiar la query para usar `news_items` directamente:

   ```dart
   // En lugar de viewed_categories, usar news_read_history o engagement_events
   final viewed = await _supabase
       .from('news_read_history')
       .select('news_items!inner(category_id)')
       .in_('user_session_id', sessionIds);
   ```

---

## 🎯 Resumen de Acciones Inmediatas

| BQ | Problema | Solución | Archivo |
|----|----------|----------|---------|
| **H.1** | Función SQL faltante | ✅ Ejecutar `2025-11-29_create_analytics_functions.sql` | `sql/2025-11-29_create_analytics_functions.sql` |
| **H.3** | Sin datos en `user_favorite_categories` | ⚠️ Agregar categorías favoritas o implementar UI | Ejecutar SQL de inserción |
| **H.3** | Posible: Sin datos en `viewed_categories` | ⚠️ Verificar y agregar tracking de vistas | Ver queries de verificación |

---

## 📊 Verificación Final

Después de aplicar las soluciones:

1. **Abre el dashboard de analytics en Flutter**
2. **H.1 debería mostrar:** 
   - Si tienes 1 usuario con dark_mode=true de 5 totales → "20.0%"
   - Si todos tienen dark_mode=false → "0.0%" (válido)
   - Si no hay usuarios en user_preferences → "0.0%" (necesitas crear registros)

3. **H.3 debería mostrar:**
   - Si tienes 3 categorías favoritas y 2 de 6 impresiones son de esas categorías → "33.3%"
   - Si no tienes categorías favoritas → "0.0%" (esperado, pero mensaje UI debería ser más claro)
   - Si viewed_categories está vacío → "Total impresiones: 0" (necesitas implementar tracking)

---

## 🔗 Referencias

**Archivos modificados/creados:**
- ✅ `sql/2025-11-29_create_analytics_functions.sql` (NUEVO)
- 📖 `lib/view_models/analytics_dashboard_viewmodel.dart` líneas 456-462 (H.1), 508-562 (H.3)
- 📖 `sql/2025-11-28_create_user_preferences.sql` (tabla existente)
- 📖 `sql/2025-11-28_create_user_favorite_categories.sql` (tabla existente)

**Queries útiles:**
- Verificar RPC: `SELECT get_dark_mode_percentage();`
- Ver preferencias: `SELECT * FROM user_preferences;`
- Ver favoritos: `SELECT * FROM user_favorite_categories;`
- Ver impresiones: `SELECT * FROM viewed_categories LIMIT 10;`
