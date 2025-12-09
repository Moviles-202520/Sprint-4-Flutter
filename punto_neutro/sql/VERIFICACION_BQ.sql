-- =====================================================
-- QUERIES DE VERIFICACIÓN PARA BUSINESS QUESTIONS
-- Ejecuta estas queries para diagnosticar el estado actual
-- NO MODIFICAN NADA - Solo lectura
-- =====================================================

-- ==========================================
-- H.1: Dark Mode Adoption
-- ==========================================

-- 1. Verificar si existe la función RPC
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name = 'get_dark_mode_percentage';
-- Si retorna 0 rows: La función NO existe (necesitas crearla O cambiar el código Flutter)

-- 2. Verificar tabla user_preferences
SELECT 
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE dark_mode = true) as dark_mode_users,
    COUNT(*) FILTER (WHERE dark_mode = false) as light_mode_users,
    ROUND((COUNT(*) FILTER (WHERE dark_mode = true)::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100, 2) as percentage
FROM user_preferences;
-- Si total_users = 0: No hay datos de preferencias (normal si los usuarios no han configurado)

-- 3. Ver algunos registros de ejemplo
SELECT user_profile_id, dark_mode, created_at 
FROM user_preferences 
LIMIT 5;


-- ==========================================
-- H.3: Personalization Effectiveness
-- ==========================================

-- 4. Verificar user_favorite_categories
SELECT 
    COUNT(*) as total_favorites,
    COUNT(DISTINCT user_profile_id) as users_with_favorites
FROM user_favorite_categories;
-- Si total_favorites = 0: Nadie ha seleccionado categorías favoritas

-- 5. Ver categorías favoritas por usuario
SELECT 
    user_profile_id,
    COUNT(*) as favorite_count,
    array_agg(category_id) as category_ids
FROM user_favorite_categories
GROUP BY user_profile_id
LIMIT 5;

-- 6. Verificar viewed_categories
SELECT 
    COUNT(*) as total_views,
    COUNT(DISTINCT user_session_id) as sessions_with_views,
    COUNT(DISTINCT category_id) as unique_categories_viewed
FROM viewed_categories;
-- Si total_views = 0: No se están registrando las vistas de categorías

-- 7. Ver estructura de viewed_categories
SELECT * FROM viewed_categories LIMIT 3;

-- 8. Verificar user_sessions (sabemos que hay 6)
SELECT 
    COUNT(*) as total_sessions,
    COUNT(DISTINCT user_profile_id) as unique_users,
    SUM(articles_viewed) as total_articles_viewed
FROM user_sessions;


-- ==========================================
-- H.5: Source Satisfaction
-- ==========================================

-- 9. Verificar news_items con source_domain
SELECT 
    COUNT(*) as total_news,
    COUNT(*) FILTER (WHERE source_domain IS NOT NULL) as with_source,
    COUNT(DISTINCT source_domain) as unique_sources,
    COUNT(DISTINCT category_id) as unique_categories
FROM news_items;
-- Si with_source = 0: No hay fuentes registradas

-- 10. Ver algunas fuentes de ejemplo
SELECT source_domain, category_id, COUNT(*) as count
FROM news_items
WHERE source_domain IS NOT NULL
GROUP BY source_domain, category_id
ORDER BY count DESC
LIMIT 10;

-- 11. Verificar ratings para esas noticias
SELECT 
    COUNT(*) as total_ratings,
    ROUND(AVG(assigned_reliability_score), 2) as avg_reliability
FROM rating_items
WHERE news_item_id IN (
    SELECT news_item_id FROM news_items WHERE source_domain IS NOT NULL
);


-- ==========================================
-- DIAGNÓSTICO COMPLETO
-- ==========================================

-- 12. Resumen de todas las tablas críticas
SELECT 
    'user_preferences' as tabla,
    COUNT(*) as registros
FROM user_preferences
UNION ALL
SELECT 'user_favorite_categories', COUNT(*) FROM user_favorite_categories
UNION ALL
SELECT 'viewed_categories', COUNT(*) FROM viewed_categories
UNION ALL
SELECT 'user_sessions', COUNT(*) FROM user_sessions
UNION ALL
SELECT 'news_items (con source)', COUNT(*) FROM news_items WHERE source_domain IS NOT NULL
UNION ALL
SELECT 'rating_items', COUNT(*) FROM rating_items;
