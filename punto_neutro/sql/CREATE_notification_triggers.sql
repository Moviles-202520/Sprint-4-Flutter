-- =========================================
-- 🔔 NOTIFICACIONES AUTOMÁTICAS
-- =========================================
-- Triggers para crear notificaciones cuando:
-- 1. Se crea una nueva noticia
-- 2. Alguien califica tu noticia
-- 3. Alguien comenta en tu noticia

BEGIN;

-- ============================================
-- PASO 0: PERMITIR INSERT EN NOTIFICATIONS
-- ============================================
-- Los triggers necesitan poder insertar notificaciones

DROP POLICY IF EXISTS "allow_insert_notifications" ON notifications;
CREATE POLICY "allow_insert_notifications"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true); -- ⚠️ Permitir que triggers inserten notificaciones

-- ============================================
-- TRIGGER 1: Notificación al crear noticia
-- ============================================

CREATE OR REPLACE FUNCTION notify_article_published()
RETURNS TRIGGER AS $$
BEGIN
    -- Crear notificación para el autor
    INSERT INTO notifications (
        user_profile_id,
        actor_user_profile_id,
        news_item_id,
        type,
        payload,
        is_read,
        created_at
    ) VALUES (
        NEW.user_profile_id,
        NEW.user_profile_id,
        NEW.news_item_id,
        'article_published',
        jsonb_build_object(
            'title', NEW.title,
            'category_id', NEW.category_id
        ),
        false,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asignar trigger a news_items
DROP TRIGGER IF EXISTS trigger_notify_article_published ON news_items;
CREATE TRIGGER trigger_notify_article_published
    AFTER INSERT ON news_items
    FOR EACH ROW
    EXECUTE FUNCTION notify_article_published();

-- ============================================
-- TRIGGER 2: Notificación al recibir rating
-- ============================================

CREATE OR REPLACE FUNCTION notify_rating_received()
RETURNS TRIGGER AS $$
DECLARE
    author_id BIGINT;
BEGIN
    -- Obtener el autor de la noticia
    SELECT user_profile_id INTO author_id
    FROM news_items
    WHERE news_item_id = NEW.news_item_id;
    
    -- Solo notificar si alguien MÁS calificó (no el mismo autor)
    IF author_id IS NOT NULL AND author_id != NEW.user_profile_id THEN
        INSERT INTO notifications (
            user_profile_id,
            actor_user_profile_id,
            news_item_id,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            author_id,
            NEW.user_profile_id,
            NEW.news_item_id,
            'rating_received',
            jsonb_build_object(
                'reliability_score', NEW.reliability_score,
                'comment', NEW.comment
            ),
            false,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asignar trigger a rating_items (NO ratings)
DROP TRIGGER IF EXISTS trigger_notify_rating_received ON rating_items;
CREATE TRIGGER trigger_notify_rating_received
    AFTER INSERT ON rating_items
    FOR EACH ROW
    EXECUTE FUNCTION notify_rating_received();

-- ============================================
-- TRIGGER 3: Notificación al recibir comentario
-- ============================================

CREATE OR REPLACE FUNCTION notify_comment_received()
RETURNS TRIGGER AS $$
DECLARE
    author_id BIGINT;
BEGIN
    -- Obtener el autor de la noticia
    SELECT user_profile_id INTO author_id
    FROM news_items
    WHERE news_item_id = NEW.news_item_id;
    
    -- Solo notificar si alguien MÁS comentó (no el mismo autor)
    IF author_id IS NOT NULL AND author_id != NEW.user_profile_id THEN
        INSERT INTO notifications (
            user_profile_id,
            actor_user_profile_id,
            news_item_id,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            author_id,
            NEW.user_profile_id,
            NEW.news_item_id,
            'comment_received',
            jsonb_build_object(
                'comment_text', NEW.comment_text
            ),
            false,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asignar trigger a comments
DROP TRIGGER IF EXISTS trigger_notify_comment_received ON comments;
CREATE TRIGGER trigger_notify_comment_received
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_comment_received();

COMMIT;

-- ✅ Listo! Ahora se generan notificaciones automáticamente
