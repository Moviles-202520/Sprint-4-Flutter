-- =============================================================================
-- Script: Optimizar feed de noticias para paginación infinita
-- Fecha: 2025-11-28
-- Descripción: Añade índices y función para cargar noticias de forma eficiente
-- =============================================================================

-- Crear índice compuesto para ordenamiento por fecha de creación
CREATE INDEX IF NOT EXISTS idx_news_items_created_at_desc 
ON public.news_items(created_at DESC);

-- Crear índice para filtrado por categoría + fecha
CREATE INDEX IF NOT EXISTS idx_news_items_category_created 
ON public.news_items(category_id, created_at DESC);

-- Función RPC para obtener noticias con paginación
-- Opción 1: Orden aleatorio (shuffle)
CREATE OR REPLACE FUNCTION get_news_feed_random(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_category_id TEXT DEFAULT NULL
)
RETURNS SETOF news_items
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.news_items
  WHERE 
    (p_category_id IS NULL OR category_id = p_category_id)
  ORDER BY random()
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Opción 2: Orden por más recientes
CREATE OR REPLACE FUNCTION get_news_feed_recent(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_category_id TEXT DEFAULT NULL
)
RETURNS SETOF news_items
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.news_items
  WHERE 
    (p_category_id IS NULL OR category_id = p_category_id)
  ORDER BY created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Opción 3: Orden mixto (más recientes con algo de aleatoriedad)
CREATE OR REPLACE FUNCTION get_news_feed_mixed(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_category_id TEXT DEFAULT NULL
)
RETURNS SETOF news_items
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.news_items
  WHERE 
    (p_category_id IS NULL OR category_id = p_category_id)
    AND created_at > NOW() - INTERVAL '30 days' -- Solo últimos 30 días
  ORDER BY 
    -- Priorizar recientes pero con algo de aleatoriedad
    (EXTRACT(EPOCH FROM created_at) * random()) DESC
  LIMIT p_limit
  OFFSET p_offset
  
  UNION ALL
  
  -- Si no hay suficientes, llenar con aleatorios de hace más de 30 días
  SELECT *
  FROM public.news_items
  WHERE 
    (p_category_id IS NULL OR category_id = p_category_id)
    AND created_at <= NOW() - INTERVAL '30 days'
  ORDER BY random()
  LIMIT GREATEST(0, p_limit - (
    SELECT COUNT(*)::INT 
    FROM public.news_items 
    WHERE 
      (p_category_id IS NULL OR category_id = p_category_id)
      AND created_at > NOW() - INTERVAL '30 days'
  ));
$$;

-- Grant de permisos para usuarios autenticados
GRANT EXECUTE ON FUNCTION get_news_feed_random TO authenticated;
GRANT EXECUTE ON FUNCTION get_news_feed_recent TO authenticated;
GRANT EXECUTE ON FUNCTION get_news_feed_mixed TO authenticated;

-- Comentarios
COMMENT ON FUNCTION get_news_feed_random IS 'Obtiene noticias en orden completamente aleatorio';
COMMENT ON FUNCTION get_news_feed_recent IS 'Obtiene noticias ordenadas por más recientes primero';
COMMENT ON FUNCTION get_news_feed_mixed IS 'Obtiene noticias recientes con aleatoriedad, prioriza contenido nuevo';

-- =============================================================================
-- Notas de implementación:
-- 
-- 1. Usa get_news_feed_recent para mostrar siempre lo más nuevo primero
-- 2. Usa get_news_feed_random para un feed tipo "explorar"
-- 3. Usa get_news_feed_mixed para balance entre novedad y descubrimiento
--
-- Ejemplo de uso desde Dart:
-- final response = await supabase
--   .rpc('get_news_feed_recent', params: {
--     'p_limit': 20,
--     'p_offset': currentPage * 20,
--     'p_category_id': selectedCategory,
--   });
-- =============================================================================
