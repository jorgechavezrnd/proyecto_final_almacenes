-- Script SQL simplificado para Supabase
-- Ejecuta este código en el SQL Editor de tu dashboard de Supabase
-- SOLO crea la función RPC para acceder a auth.users, sin tablas adicionales

-- Eliminar función existente si existe (para evitar conflictos de tipos)
DROP FUNCTION IF EXISTS public.get_auth_users_admin();

-- Función RPC para obtener todos los usuarios de auth.users (solo para admins)
CREATE OR REPLACE FUNCTION public.get_auth_users_admin()
RETURNS TABLE (
    id UUID,
    email CHARACTER VARYING(255),
    raw_user_meta_data JSONB,
    last_sign_in_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario actual es admin
    IF NOT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data->>'role')::text = 'admin'
    ) THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Retornar todos los usuarios directamente desde auth.users
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.raw_user_meta_data,
        u.last_sign_in_at,
        u.created_at
    FROM auth.users u
    ORDER BY u.created_at DESC;
END;
$$;

-- Comentario explicativo
COMMENT ON FUNCTION public.get_auth_users_admin() IS 'Función RPC para obtener usuarios de auth.users (solo administradores)';

-- Eliminar función alternativa si existe
DROP FUNCTION IF EXISTS public.get_auth_users_simple();

-- FUNCIÓN ALTERNATIVA: Si la anterior no funciona por tipos de datos
CREATE OR REPLACE FUNCTION public.get_auth_users_simple()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Verificar que el usuario actual es admin
    IF NOT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data->>'role')::text = 'admin'
    ) THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Retornar todos los usuarios como JSON
    SELECT json_agg(
        json_build_object(
            'id', u.id,
            'email', u.email,
            'raw_user_meta_data', u.raw_user_meta_data,
            'last_sign_in_at', u.last_sign_in_at,
            'created_at', u.created_at
        ) ORDER BY u.created_at DESC
    ) INTO result
    FROM auth.users u;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- INSTRUCCIONES DE USO:
-- 1. Ejecuta este script COMPLETO en el SQL Editor de Supabase
-- 2. Las funciones get_auth_users_admin() y get_auth_users_simple() estarán disponibles
-- 3. Solo usuarios con role 'admin' en sus metadatos pueden ejecutar estas funciones
-- 4. La primera función devuelve una tabla, la segunda devuelve JSON
-- 5. Si ya tenías funciones anteriores, se eliminarán y recrearán con los tipos correctos

-- NOTA: Si este método no funciona por restricciones de RLS en auth.users,
-- tendrías que usar un Edge Function o implementar políticas más complejas.

-- COMENTARIOS FINALES
COMMENT ON FUNCTION public.get_auth_users_simple() IS 'Función RPC alternativa que retorna usuarios como JSON (solo administradores)';