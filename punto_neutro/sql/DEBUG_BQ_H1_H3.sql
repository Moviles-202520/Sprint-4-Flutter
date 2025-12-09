-- =====================================================
-- DEBUG: Verificar exactamente qué datos está consultando H.1 y H.3
-- =====================================================

-- ==========================================
-- H.1: Dark Mode - Debug
-- ==========================================

-- 1. Ver TODOS los registros de user_preferences (lo que ve la app SIN limit)
SELECT 
    user_profile_id,
    dark_mode,
    created_at,
    updated_at
FROM user_preferences
ORDER BY created_at DESC;

-- 2. Ver lo que consulta la app (últimos 100)
SELECT 
    user_profile_id,
    dark_mode,
    created_at
FROM user_preferences
ORDER BY created_at DESC
LIMIT 100;

-- 3. Contar por dark_mode (SIN limit)
SELECT 
    dark_mode,
    COUNT(*) as count
FROM user_preferences
GROUP BY dark_mode;

-- 4. Ver user_profile_id del usuario actual autenticado
SELECT 
    user_profile_id,
    user_auth_id,
    display_name,
    created_at
FROM user_profiles
WHERE user_auth_id = auth.uid();

-- 5. Ver SOLO la preferencia del usuario actual
SELECT 
    up.user_profile_id,
    up.dark_mode,
    up.created_at,
    u.display_name
FROM user_preferences up
JOIN user_profiles u ON up.user_profile_id = u.user_profile_id
WHERE u.user_auth_id = auth.uid();


-- ==========================================
-- H.3: Personalization - Debug
-- ==========================================

-- 6. Ver categorías favoritas del usuario actual
SELECT 
    ufc.user_profile_id,
    ufc.category_id,
    c.name as category_name
FROM user_favorite_categories ufc
JOIN categories c ON ufc.category_id = c.category_id
JOIN user_profiles up ON ufc.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid();

-- 7. Ver últimas 10 sesiones del usuario actual
SELECT 
    us.user_session_id,
    us.user_profile_id,
    us.articles_viewed,
    us.duration_seconds,
    us.session_start,
    us.session_end
FROM user_sessions us
JOIN user_profiles up ON us.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid()
ORDER BY us.session_start DESC
LIMIT 10;

-- 8. Ver viewed_categories para esas sesiones
SELECT 
    vc.user_session_id,
    vc.category_id,
    c.name as category_name,
    COUNT(*) as views
FROM viewed_categories vc
JOIN categories c ON vc.category_id = c.category_id
WHERE vc.user_session_id IN (
    SELECT us.user_session_id
    FROM user_sessions us
    JOIN user_profiles up ON us.user_profile_id = up.user_profile_id
    WHERE up.user_auth_id = auth.uid()
    ORDER BY us.session_start DESC
    LIMIT 10
)
GROUP BY vc.user_session_id, vc.category_id, c.name
ORDER BY vc.user_session_id DESC;

-- 9. Ver news_read_history del usuario actual (alternativa)
SELECT 
    nrh.read_id,
    nrh.news_item_id,
    ni.category_id,
    c.name as category_name,
    nrh.read_at
FROM news_read_history nrh
JOIN news_items ni ON nrh.news_item_id = ni.news_item_id
JOIN categories c ON ni.category_id = c.category_id
JOIN user_profiles up ON nrh.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid()
ORDER BY nrh.read_at DESC
LIMIT 50;

-- 10. Verificar si hay ALGÚN dato en viewed_categories
SELECT COUNT(*) as total_records FROM viewed_categories;

-- 11. Ver estructura de viewed_categories (primeros 5 registros)
SELECT * FROM viewed_categories LIMIT 5;


-- ==========================================
-- RESUMEN DIAGNÓSTICO
-- ==========================================

-- 12. Resumen del usuario actual
SELECT 
    'Tu user_profile_id' as info,
    up.user_profile_id as valor
FROM user_profiles up
WHERE up.user_auth_id = auth.uid()
UNION ALL
SELECT 
    'Dark mode activado',
    CASE WHEN pref.dark_mode THEN 'true' ELSE 'false' END::TEXT
FROM user_preferences pref
JOIN user_profiles up ON pref.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid()
UNION ALL
SELECT 
    'Categorías favoritas (count)',
    COUNT(*)::TEXT
FROM user_favorite_categories ufc
JOIN user_profiles up ON ufc.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid()
UNION ALL
SELECT 
    'Sesiones totales',
    COUNT(*)::TEXT
FROM user_sessions us
JOIN user_profiles up ON us.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid()
UNION ALL
SELECT 
    'Lecturas totales',
    COUNT(*)::TEXT
FROM news_read_history nrh
JOIN user_profiles up ON nrh.user_profile_id = up.user_profile_id
WHERE up.user_auth_id = auth.uid();
