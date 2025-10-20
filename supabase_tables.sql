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

-- Política adicional: permitir actualización de cantidad para usuarios autenticados (para ventas)
CREATE POLICY "Enable quantity update for authenticated users" ON products
    FOR UPDATE USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

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

-- ============================================================================
-- TABLAS DE VENTAS (SALES SYSTEM)
-- ============================================================================

-- 11. Tabla de Ventas (Sales)
CREATE TABLE sales (
    id TEXT PRIMARY KEY,
    warehouse_id TEXT NOT NULL,
    user_id UUID NOT NULL,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.0,
    total_amount DECIMAL(10,2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'transfer', 'credit')),
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled', 'refunded')),
    notes TEXT,
    sale_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- 12. Tabla de Elementos de Venta (Sale Items)
CREATE TABLE sale_items (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    created_at TIMESTAMPTZ DEFAULT now(),
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- 13. Índices para optimizar consultas de ventas
CREATE INDEX idx_sales_warehouse_id ON sales(warehouse_id);
CREATE INDEX idx_sales_user_id ON sales(user_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_status ON sales(status);
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items(product_id);

-- 14. Trigger para actualizar updated_at en ventas
CREATE OR REPLACE FUNCTION update_sales_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_updated_at
    BEFORE UPDATE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_sales_updated_at();

-- 15. Políticas RLS para Sales
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

-- Usuarios autenticados pueden ver sus propias ventas o las de su almacén (si son admin)
CREATE POLICY "Enable read for users" ON sales
    FOR SELECT USING (
        auth.uid() = user_id OR
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- Usuarios autenticados pueden crear ventas
CREATE POLICY "Enable insert for authenticated users" ON sales
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Solo el usuario que creó la venta o un admin puede actualizarla
CREATE POLICY "Enable update for owner or admin" ON sales
    FOR UPDATE USING (
        auth.uid() = user_id OR
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- Solo admins pueden eliminar ventas
CREATE POLICY "Enable delete for admin" ON sales
    FOR DELETE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- 16. Políticas RLS para Sale Items
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- Los usuarios pueden ver items de ventas que pueden ver
CREATE POLICY "Enable read for sale owners" ON sale_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sales s 
            WHERE s.id = sale_items.sale_id 
            AND (
                s.user_id = auth.uid() OR
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            )
        )
    );

-- Usuarios autenticados pueden crear items de venta
CREATE POLICY "Enable insert for authenticated users" ON sale_items
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Solo el dueño de la venta o admin puede actualizar items
CREATE POLICY "Enable update for sale owner or admin" ON sale_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM sales s 
            WHERE s.id = sale_items.sale_id 
            AND (
                s.user_id = auth.uid() OR
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            )
        )
    );

-- Solo admins pueden eliminar items de venta
CREATE POLICY "Enable delete for admin" ON sale_items
    FOR DELETE USING (
        auth.jwt() ->> 'role' = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- 17. Función para obtener estadísticas de ventas
CREATE OR REPLACE FUNCTION get_sales_stats(
    warehouse_id_param TEXT DEFAULT NULL,
    start_date TIMESTAMPTZ DEFAULT NULL,
    end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_sales', COUNT(*),
        'completed_sales', COUNT(*) FILTER (WHERE status = 'completed'),
        'cancelled_sales', COUNT(*) FILTER (WHERE status = 'cancelled'),
        'total_revenue', COALESCE(SUM(total_amount) FILTER (WHERE status = 'completed'), 0),
        'total_items_sold', COALESCE(SUM(si.total_quantity), 0),
        'average_sale_amount', COALESCE(AVG(total_amount) FILTER (WHERE status = 'completed'), 0)
    )
    INTO result
    FROM sales s
    LEFT JOIN (
        SELECT sale_id, SUM(quantity) as total_quantity
        FROM sale_items
        GROUP BY sale_id
    ) si ON s.id = si.sale_id
    WHERE (warehouse_id_param IS NULL OR s.warehouse_id = warehouse_id_param)
    AND (start_date IS NULL OR s.sale_date >= start_date)
    AND (end_date IS NULL OR s.sale_date <= end_date);
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18. Función para obtener top productos vendidos
CREATE OR REPLACE FUNCTION get_top_selling_products(
    warehouse_id_param TEXT DEFAULT NULL,
    start_date TIMESTAMPTZ DEFAULT NULL,
    end_date TIMESTAMPTZ DEFAULT NULL,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id TEXT,
    product_name TEXT,
    total_quantity INTEGER,
    total_revenue DECIMAL(10,2),
    sale_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        SUM(si.quantity)::INTEGER as total_quantity,
        SUM(si.total_price) as total_revenue,
        COUNT(DISTINCT s.id)::INTEGER as sale_count
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.status = 'completed'
    AND (warehouse_id_param IS NULL OR s.warehouse_id = warehouse_id_param)
    AND (start_date IS NULL OR s.sale_date >= start_date)
    AND (end_date IS NULL OR s.sale_date <= end_date)
    GROUP BY p.id, p.name
    ORDER BY total_quantity DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;