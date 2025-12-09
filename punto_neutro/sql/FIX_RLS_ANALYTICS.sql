-- =====================================================
-- VERIFICAR RLS Y POLÍTICAS DE SEGURIDAD
-- =====================================================

-- 1. Ver si RLS está habilitado en user_preferences
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'user_preferences';

-- 2. Ver las políticas RLS de user_preferences
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_preferences';

-- 3. SOLUCIÓN TEMPORAL: Desactivar SELECT filtrado por usuario
-- Para analytics, necesitamos ver TODOS los user_preferences
DROP POLICY IF EXISTS "Users can view own preferences" ON user_preferences;

CREATE POLICY "Analytics can view all preferences"
    ON user_preferences
    FOR SELECT
    TO authenticated
    USING (true); -- Permitir ver todos los registros

-- 4. Verificar que ahora sí trae los 2 usuarios
SELECT 
    user_profile_id,
    dark_mode,
    created_at
FROM user_preferences
ORDER BY created_at DESC;
