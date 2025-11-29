-- =========================================
-- 🚨 URGENTE: PERMITIR CREAR/EDITAR NOTICIAS
-- =========================================
-- Ejecuta esto AHORA en Supabase SQL Editor
-- 1. Arregla las políticas RLS
-- 2. Resetea la secuencia de news_item_id

BEGIN;

-- ============================================
-- PASO 1: ARREGLAR SECUENCIA (Evitar duplicados)
-- ============================================
-- Resetear la secuencia al siguiente valor disponible
SELECT setval(
    pg_get_serial_sequence('public.news_items', 'news_item_id'),
    COALESCE((SELECT MAX(news_item_id) FROM public.news_items), 0) + 1,
    false
);

-- ============================================
-- PASO 2: POLÍTICAS RLS PERMISIVAS
-- ============================================

-- Borrar políticas restrictivas anteriores
DROP POLICY IF EXISTS "news_items_insert_own" ON public.news_items;
DROP POLICY IF EXISTS "news_items_update_own" ON public.news_items;
DROP POLICY IF EXISTS "news_items_delete_own" ON public.news_items;
DROP POLICY IF EXISTS "news_items_insert_all" ON public.news_items;
DROP POLICY IF EXISTS "news_items_update_all" ON public.news_items;
DROP POLICY IF EXISTS "news_items_delete_all" ON public.news_items;
DROP POLICY IF EXISTS "allow_insert_news" ON public.news_items;
DROP POLICY IF EXISTS "allow_update_news" ON public.news_items;
DROP POLICY IF EXISTS "allow_delete_news" ON public.news_items;

-- 1. PERMITIR INSERT (Crear noticias)
CREATE POLICY "allow_insert_news"
ON public.news_items
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 2. PERMITIR UPDATE (Editar noticias)
CREATE POLICY "allow_update_news"
ON public.news_items
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 3. PERMITIR DELETE (Borrar noticias)
CREATE POLICY "allow_delete_news"
ON public.news_items
FOR DELETE
TO authenticated
USING (true);

COMMIT;

-- ✅ Listo! Ahora puedes crear/editar/borrar noticias sin restricciones
