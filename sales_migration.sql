-- MIGRACIÓN PARA AGREGAR TABLAS DE VENTAS
-- Ejecutar este script en el SQL Editor de Supabase para agregar solo las tablas de ventas

-- ============================================================================
-- VERIFICAR SI LAS TABLAS YA EXISTEN ANTES DE CREARLAS
-- ============================================================================

-- 1. Crear tabla de ventas solo si no existe
CREATE TABLE IF NOT EXISTS sales (
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

-- 2. Crear tabla de elementos de venta solo si no existe
CREATE TABLE IF NOT EXISTS sale_items (
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

-- 3. Crear índices solo si no existen
CREATE INDEX IF NOT EXISTS idx_sales_warehouse_id ON sales(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);

-- 4. Crear función para actualizar updated_at en ventas
CREATE OR REPLACE FUNCTION update_sales_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Crear trigger solo si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trigger_update_sales_updated_at'
    ) THEN
        CREATE TRIGGER trigger_update_sales_updated_at
            BEFORE UPDATE ON sales
            FOR EACH ROW
            EXECUTE FUNCTION update_sales_updated_at();
    END IF;
END $$;

-- 6. Habilitar RLS en las nuevas tablas
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- 7. Crear políticas RLS para Sales (solo si no existen)
DO $$
BEGIN
    -- Política de lectura para sales
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sales' AND policyname = 'Enable read for users'
    ) THEN
        CREATE POLICY "Enable read for users" ON sales
            FOR SELECT USING (
                auth.uid() = user_id OR
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            );
    END IF;

    -- Política de inserción para sales
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sales' AND policyname = 'Enable insert for authenticated users'
    ) THEN
        CREATE POLICY "Enable insert for authenticated users" ON sales
            FOR INSERT WITH CHECK (auth.role() = 'authenticated');
    END IF;

    -- Política de actualización para sales
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sales' AND policyname = 'Enable update for owner or admin'
    ) THEN
        CREATE POLICY "Enable update for owner or admin" ON sales
            FOR UPDATE USING (
                auth.uid() = user_id OR
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            );
    END IF;

    -- Política de eliminación para sales
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sales' AND policyname = 'Enable delete for admin'
    ) THEN
        CREATE POLICY "Enable delete for admin" ON sales
            FOR DELETE USING (
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            );
    END IF;
END $$;

-- 8. Crear políticas RLS para Sale Items (solo si no existen)
DO $$
BEGIN
    -- Política de lectura para sale_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sale_items' AND policyname = 'Enable read for sale owners'
    ) THEN
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
    END IF;

    -- Política de inserción para sale_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sale_items' AND policyname = 'Enable insert for authenticated users'
    ) THEN
        CREATE POLICY "Enable insert for authenticated users" ON sale_items
            FOR INSERT WITH CHECK (auth.role() = 'authenticated');
    END IF;

    -- Política de actualización para sale_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sale_items' AND policyname = 'Enable update for sale owner or admin'
    ) THEN
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
    END IF;

    -- Política de eliminación para sale_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'sale_items' AND policyname = 'Enable delete for admin'
    ) THEN
        CREATE POLICY "Enable delete for admin" ON sale_items
            FOR DELETE USING (
                auth.jwt() ->> 'role' = 'admin' OR 
                (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
            );
    END IF;
END $$;

-- 9. Crear función para estadísticas de ventas
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

-- 10. Crear función para productos más vendidos
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

-- ============================================================================
-- MIGRACIÓN COMPLETADA
-- ============================================================================

-- Verificar que las tablas se crearon correctamente
SELECT 'Tablas de ventas creadas exitosamente' as status;
SELECT 
    tablename, 
    'EXISTS' as status 
FROM pg_tables 
WHERE tablename IN ('sales', 'sale_items') 
AND schemaname = 'public';