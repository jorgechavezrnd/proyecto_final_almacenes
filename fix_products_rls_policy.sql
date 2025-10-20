-- Script para corregir las políticas RLS de la tabla products
-- Ejecutar este script en el SQL Editor de Supabase

-- Agregar política que permite a usuarios autenticados actualizar productos (necesario para ventas)
CREATE POLICY "Enable quantity update for authenticated users" ON products
    FOR UPDATE USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Verificar las políticas actuales (opcional - para confirmar)
-- Descomenta las siguientes líneas si quieres ver todas las políticas:
-- SELECT * FROM pg_policies WHERE tablename = 'products';