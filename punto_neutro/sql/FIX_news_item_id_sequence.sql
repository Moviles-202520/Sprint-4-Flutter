-- =========================================
-- 🚨 ARREGLAR SECUENCIA DE news_item_id
-- =========================================
-- Problema: Error "duplicate key value violates unique constraint"
-- Causa: La secuencia está desincronizada con los valores actuales
-- Solución: Resetear la secuencia al máximo valor + 1

BEGIN;

-- 1. Ver el máximo news_item_id actual
SELECT MAX(news_item_id) FROM public.news_items;

-- 2. Resetear la secuencia al siguiente valor disponible
SELECT setval(
    pg_get_serial_sequence('public.news_items', 'news_item_id'),
    COALESCE((SELECT MAX(news_item_id) FROM public.news_items), 0) + 1,
    false
);

-- 3. Verificar que la secuencia está correcta
SELECT currval(pg_get_serial_sequence('public.news_items', 'news_item_id'));

COMMIT;

-- ✅ Ahora puedes crear noticias sin error de duplicados
