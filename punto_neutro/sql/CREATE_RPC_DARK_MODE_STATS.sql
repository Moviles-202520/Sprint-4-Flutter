-- =====================================================
-- OPCIÓN 2: Crear función RPC que bypasea RLS
-- =====================================================

-- Crear función para obtener estadísticas de dark mode
CREATE OR REPLACE FUNCTION get_dark_mode_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Ejecuta con permisos del owner (bypasea RLS)
AS $$
DECLARE
    total_users INT;
    dark_mode_users INT;
    percentage NUMERIC;
    result JSON;
BEGIN
    -- Contar total de usuarios
    SELECT COUNT(*) INTO total_users FROM user_preferences;
    
    -- Contar usuarios con dark mode
    SELECT COUNT(*) INTO dark_mode_users 
    FROM user_preferences 
    WHERE dark_mode = true;
    
    -- Calcular porcentaje
    IF total_users > 0 THEN
        percentage := ROUND((dark_mode_users::NUMERIC / total_users::NUMERIC) * 100, 2);
    ELSE
        percentage := 0.0;
    END IF;
    
    -- Construir JSON
    result := json_build_object(
        'dark_mode_percentage', percentage,
        'total_users', total_users,
        'dark_mode_users', dark_mode_users
    );
    
    RETURN result;
END;
$$;

-- Dar permisos
GRANT EXECUTE ON FUNCTION get_dark_mode_stats() TO authenticated;

-- Probar
SELECT get_dark_mode_stats();
