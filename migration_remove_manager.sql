-- Script de migración para eliminar funcionalidad de Manager ID
-- Ejecutar este script EN LUGAR del supabase_tables.sql completo

-- 1. Eliminar las funciones RPC innecesarias que agregamos
DROP FUNCTION IF EXISTS get_users_list();
DROP FUNCTION IF EXISTS get_user_by_id(UUID);

-- 2. Eliminar el campo manager_id de la tabla warehouses si existe
ALTER TABLE warehouses DROP COLUMN IF EXISTS manager_id;

-- 3. Verificar que las políticas RLS estén correctas para administradores
-- Las políticas existentes deberían seguir funcionando

-- 4. Asegurarse de que los triggers estén funcionando
-- Los triggers existentes deberían seguir funcionando

-- Opcional: Verificar el esquema actual de la tabla warehouses
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'warehouses' 
-- ORDER BY ordinal_position;

-- El esquema final debería ser:
-- id (TEXT)
-- name (TEXT)
-- description (TEXT)
-- address (TEXT)  
-- city (TEXT)
-- phone (TEXT)
-- email (TEXT)
-- is_active (BOOLEAN)
-- created_at (TIMESTAMPTZ)
-- updated_at (TIMESTAMPTZ)
-- last_sync_at (TIMESTAMPTZ)