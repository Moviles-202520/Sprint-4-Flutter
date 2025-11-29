-- =========================================
-- HABILITAR CREACIÓN DE NOTICIAS
-- =========================================
-- Este script permite que usuarios autenticados puedan:
-- 1. Crear nuevas noticias (INSERT)
-- 2. Actualizar sus propias noticias (UPDATE)
-- 3. Eliminar sus propias noticias (DELETE)

BEGIN;

-- ============================================
-- 1. POLÍTICA INSERT: Crear noticias
-- ============================================
-- Permite que cualquier usuario autenticado cree noticias
-- El user_profile_id debe coincidir con el usuario actual

DROP POLICY IF EXISTS "news_items_insert_own" ON public.news_items;

CREATE POLICY "news_items_insert_own"
ON public.news_items
FOR INSERT
TO authenticated
WITH CHECK (
  -- Verificar que el user_profile_id corresponde al usuario actual
  user_profile_id IN (
    SELECT user_profile_id 
    FROM public.user_profiles 
    WHERE user_auth_id = auth.uid()
  )
);

COMMENT ON POLICY "news_items_insert_own" ON public.news_items IS
'Permite a usuarios autenticados crear noticias. Requiere que user_profile_id coincida con su perfil.';


-- ============================================
-- 2. POLÍTICA UPDATE: Actualizar propias noticias
-- ============================================
-- Permite que los usuarios actualicen solo sus propias noticias

DROP POLICY IF EXISTS "news_items_update_own" ON public.news_items;

CREATE POLICY "news_items_update_own"
ON public.news_items
FOR UPDATE
TO authenticated
USING (
  -- Solo puede actualizar sus propias noticias
  user_profile_id IN (
    SELECT user_profile_id 
    FROM public.user_profiles 
    WHERE user_auth_id = auth.uid()
  )
)
WITH CHECK (
  -- Verificar que no cambien el autor a otro usuario
  user_profile_id IN (
    SELECT user_profile_id 
    FROM public.user_profiles 
    WHERE user_auth_id = auth.uid()
  )
);

COMMENT ON POLICY "news_items_update_own" ON public.news_items IS
'Permite a usuarios actualizar solo las noticias que ellos mismos crearon.';


-- ============================================
-- 3. POLÍTICA DELETE: Eliminar propias noticias
-- ============================================
-- Permite que los usuarios eliminen solo sus propias noticias

DROP POLICY IF EXISTS "news_items_delete_own" ON public.news_items;

CREATE POLICY "news_items_delete_own"
ON public.news_items
FOR DELETE
TO authenticated
USING (
  -- Solo puede eliminar sus propias noticias
  user_profile_id IN (
    SELECT user_profile_id 
    FROM public.user_profiles 
    WHERE user_auth_id = auth.uid()
  )
);

COMMENT ON POLICY "news_items_delete_own" ON public.news_items IS
'Permite a usuarios eliminar solo las noticias que ellos mismos crearon.';


COMMIT;

-- ============================================
-- VERIFICACIÓN
-- ============================================
-- Para verificar que las políticas se crearon correctamente:

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
WHERE tablename = 'news_items'
ORDER BY cmd, policyname;

-- ============================================
-- NOTAS IMPORTANTES
-- ============================================
-- 
-- 1. Estas políticas requieren que:
--    - El usuario esté autenticado (auth.uid() no sea NULL)
--    - El user_profile_id exista en user_profiles
--    - El user_auth_id coincida con auth.uid()
--
-- 2. Si necesitas permitir creación anónima o sin restricciones:
--    Cambia WITH CHECK (true) en la política INSERT
--
-- 3. Para testing rápido, puedes usar:
--    DROP POLICY IF EXISTS "news_items_insert_own" ON public.news_items;
--    CREATE POLICY "news_items_insert_all" ON public.news_items
--    FOR INSERT TO authenticated WITH CHECK (true);
