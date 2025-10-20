-- Script temporal para deshabilitar RLS en products (para testing)
-- ADVERTENCIA: Esto permite acceso completo a la tabla products
-- Solo usar temporalmente para testing, luego habilitar RLS nuevamente

-- Opción 1: Deshabilitar RLS temporalmente (MÁS FÁCIL)
ALTER TABLE products DISABLE ROW LEVEL SECURITY;

-- Opción 2: Si prefieres mantener RLS pero hacer más permisivo
-- Descomenta las siguientes líneas y comenta la línea de arriba:
-- DROP POLICY IF EXISTS "Enable update for admin users" ON products;
-- CREATE POLICY "products_allow_all" ON products FOR ALL USING (true) WITH CHECK (true);

-- Para verificar el estado actual de RLS:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'products';