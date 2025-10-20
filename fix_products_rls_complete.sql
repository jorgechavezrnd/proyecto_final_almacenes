-- Script para corregir completamente las políticas RLS de la tabla products
-- Ejecutar este script en el SQL Editor de Supabase

-- 1. Eliminar todas las políticas existentes para products
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON products;
DROP POLICY IF EXISTS "Enable insert for admin users" ON products;
DROP POLICY IF EXISTS "Enable update for admin users" ON products;
DROP POLICY IF EXISTS "Enable quantity update for authenticated users" ON products;
DROP POLICY IF EXISTS "Enable delete for admin users" ON products;

-- 2. Crear nuevas políticas más permisivas para products
-- Política de lectura: todos los usuarios autenticados pueden leer
CREATE POLICY "products_select_policy" ON products
    FOR SELECT USING (auth.role() = 'authenticated');

-- Política de inserción: todos los usuarios autenticados pueden insertar
CREATE POLICY "products_insert_policy" ON products
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Política de actualización: todos los usuarios autenticados pueden actualizar
CREATE POLICY "products_update_policy" ON products
    FOR UPDATE USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Política de eliminación: todos los usuarios autenticados pueden eliminar
CREATE POLICY "products_delete_policy" ON products
    FOR DELETE USING (auth.role() = 'authenticated');

-- 3. Verificar que las políticas se crearon correctamente
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'products'
ORDER BY policyname;