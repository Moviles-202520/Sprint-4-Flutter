-- Script para insertar notificaciones de prueba
-- Ejecuta este script en Supabase SQL Editor para ver notificaciones en la app

-- Configuración para user_profile_id = 6
-- actor_user_profile_id = 6
-- news_item_id = 1

-- Ejemplo 1: Notificación de rating recibido
INSERT INTO notifications (
    user_profile_id,
    actor_user_profile_id,
    news_item_id,
    type,
    payload,
    is_read,
    created_at
) VALUES (
    6,
    6,
    1,
    'rating_received',
    '{"rating_score": 5}'::jsonb,
    false,
    NOW() - INTERVAL '1 hour'
);

-- Ejemplo 2: Notificación de comentario recibido
INSERT INTO notifications (
    user_profile_id,
    actor_user_profile_id,
    news_item_id,
    type,
    payload,
    is_read,
    created_at
) VALUES (
    6,
    6,
    1,
    'comment_received',
    '{"comment_text": "¡Excelente artículo! Muy informativo."}'::jsonb,
    false,
    NOW() - INTERVAL '2 hours'
);

-- Ejemplo 3: Notificación de artículo publicado
INSERT INTO notifications (
    user_profile_id,
    news_item_id,
    type,
    payload,
    is_read,
    created_at
) VALUES (
    6,
    1,
    'article_published',
    '{"status": "approved"}'::jsonb,
    false,
    NOW() - INTERVAL '30 minutes'
);

-- Ejemplo 4: Notificación del sistema
INSERT INTO notifications (
    user_profile_id,
    type,
    payload,
    is_read,
    created_at
) VALUES (
    6,
    'system',
    '{"message": "¡Bienvenido a Punto Neutro! Tu cuenta ha sido verificada correctamente."}'::jsonb,
    false,
    NOW() - INTERVAL '5 minutes'
);

-- Verificar que las notificaciones se insertaron
SELECT 
    notification_id,
    type,
    payload,
    is_read,
    created_at
FROM notifications 
WHERE user_profile_id = 6
ORDER BY created_at DESC
LIMIT 10;
