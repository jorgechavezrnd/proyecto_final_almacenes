-- SQL Scripts para crear las tablas del sistema de inventario en Supabase
-- Ejecutar estos scripts en el SQL Editor de Supabase

-- 1. Tabla de Almacenes (Warehouses)
CREATE TABLE warehouses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    city TEXT,
    phone TEXT,
    email TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_sync_at TIMESTAMPTZ
);

-- 2. Tabla de Productos (Products)
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    warehouse_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    sku TEXT NOT NULL UNIQUE,
    barcode TEXT,
    category TEXT,
    price DECIMAL(10,2) DEFAULT 0.0,
    cost DECIMAL(10,2) DEFAULT 0.0,
    quantity INTEGER DEFAULT 0,
    min_stock INTEGER DEFAULT 0,
    max_stock INTEGER,
    unit TEXT DEFAULT 'unit',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_sync_at TIMESTAMPTZ,
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

-- 3. Tabla de Movimientos de Inventario (Inventory Movements)
CREATE TABLE inventory_movements (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    warehouse_id TEXT NOT NULL,
    user_id UUID NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('in', 'out', 'adjustment', 'transfer')),
    quantity INTEGER NOT NULL,
    previous_stock INTEGER NOT NULL,
    new_stock INTEGER NOT NULL,
    reason TEXT,
    reference_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- 4. Crear índices para mejorar el rendimiento
CREATE INDEX idx_products_warehouse_id ON products(warehouse_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_warehouse_id ON inventory_movements(warehouse_id);
CREATE INDEX idx_inventory_movements_user_id ON inventory_movements(user_id);
CREATE INDEX idx_inventory_movements_created_at ON inventory_movements(created_at);

-- 5. Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 6. Triggers para actualizar updated_at
CREATE TRIGGER update_warehouses_updated_at 
    BEFORE UPDATE ON warehouses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_movements_updated_at 
    BEFORE UPDATE ON inventory_movements 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 7. Row Level Security (RLS) - Configuración básica
-- Habilitar RLS en todas las tablas
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;

-- 8. Políticas de seguridad básicas (ajustar según necesidades)
-- Todos los usuarios autenticados pueden leer
CREATE POLICY "Enable read access for authenticated users" ON warehouses
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable read access for authenticated users" ON products
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable read access for authenticated users" ON inventory_movements
    FOR SELECT USING (auth.role() = 'authenticated');

-- Solo administradores pueden insertar/actualizar/eliminar almacenes
CREATE POLICY "Enable insert for admin users" ON warehouses
    FOR INSERT WITH CHECK (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

CREATE POLICY "Enable update for admin users" ON warehouses
    FOR UPDATE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

CREATE POLICY "Enable delete for admin users" ON warehouses
    FOR DELETE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- Solo administradores pueden insertar/actualizar/eliminar productos
CREATE POLICY "Enable insert for admin users" ON products
    FOR INSERT WITH CHECK (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

CREATE POLICY "Enable update for admin users" ON products
    FOR UPDATE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

CREATE POLICY "Enable delete for admin users" ON products
    FOR DELETE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- Usuarios autenticados pueden crear movimientos de inventario
CREATE POLICY "Enable insert for authenticated users" ON inventory_movements
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Solo el usuario que creó el movimiento o un admin puede actualizarlo
CREATE POLICY "Enable update for owner or admin" ON inventory_movements
    FOR UPDATE USING (
        auth.uid() = user_id OR
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- 9. Función para obtener estadísticas de inventario
CREATE OR REPLACE FUNCTION get_inventory_stats(warehouse_id_param TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_products', COUNT(*),
        'active_products', COUNT(*) FILTER (WHERE is_active = true),
        'low_stock_products', COUNT(*) FILTER (WHERE quantity <= min_stock AND is_active = true),
        'total_value', COALESCE(SUM(quantity * price), 0),
        'categories', COUNT(DISTINCT category) FILTER (WHERE category IS NOT NULL)
    )
    INTO result
    FROM products
    WHERE (warehouse_id_param IS NULL OR warehouse_id = warehouse_id_param);
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Función para obtener productos con stock bajo
CREATE OR REPLACE FUNCTION get_low_stock_products(warehouse_id_param TEXT DEFAULT NULL)
RETURNS TABLE (
    id TEXT,
    warehouse_id TEXT,
    name TEXT,
    sku TEXT,
    quantity INTEGER,
    min_stock INTEGER,
    category TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.warehouse_id, p.name, p.sku, p.quantity, p.min_stock, p.category
    FROM products p
    WHERE p.is_active = true 
    AND p.quantity <= p.min_stock
    AND (warehouse_id_param IS NULL OR p.warehouse_id = warehouse_id_param)
    ORDER BY p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comentarios sobre la implementación:
-- 1. Ejecutar estos scripts en el SQL Editor de Supabase
-- 2. Ajustar las políticas de RLS según los requerimientos específicos
-- 3. Considerar agregar más índices según los patrones de consulta
-- 4. Las funciones están marcadas como SECURITY DEFINER para permitir acceso controlado
-- 5. Los triggers mantienen updated_at actualizado automáticamente
-- 6. Los usuarios con rol ADMIN pueden gestionar todos los almacenes