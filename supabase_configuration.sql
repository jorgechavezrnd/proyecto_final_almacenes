-- ============================================================================
-- CONFIGURACIÓN COMPLETA DE SUPABASE PARA SISTEMA DE ALMACENES
-- ============================================================================
-- 
-- Este archivo contiene todos los scripts SQL necesarios para configurar
-- la aplicación de gestión de almacenes desde cero en Supabase.
--
-- INSTRUCCIONES:
-- 1. Ejecuta este script COMPLETO en el SQL Editor de tu dashboard de Supabase
-- 2. Asegúrate de tener permisos de administrador en tu proyecto de Supabase
-- 3. Este script creará todas las tablas, índices, políticas RLS y funciones necesarias
--
-- IMPORTANTE: Este script es seguro ejecutar múltiples veces ya que usa
-- CREATE TABLE IF NOT EXISTS y DROP ... IF EXISTS
--
-- ============================================================================

-- ============================================================================
-- 1. CREACIÓN DE TABLAS PRINCIPALES
-- ============================================================================

-- Tabla de Almacenes (Warehouses)
CREATE TABLE IF NOT EXISTS warehouses (
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

-- Tabla de Productos (Products)
CREATE TABLE IF NOT EXISTS products (
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

-- Tabla de Movimientos de Inventario (Inventory Movements)
CREATE TABLE IF NOT EXISTS inventory_movements (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    warehouse_id TEXT NOT NULL,
    user_id UUID NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('in', 'out', 'adjustment', 'transfer')),
    quantity INTEGER NOT NULL,
    previous_stock INTEGER NOT NULL,
    new_stock INTEGER NOT NULL,
    unit_cost DECIMAL(10,2),
    total_cost DECIMAL(10,2),
    reference_number TEXT,
    notes TEXT,
    movement_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- Tabla de Ventas (Sales)
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

-- Tabla de Elementos de Venta (Sale Items)
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

-- Tabla de Proveedores (Suppliers)
CREATE TABLE IF NOT EXISTS suppliers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    country TEXT,
    tax_id TEXT,
    payment_terms TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 2. CREACIÓN DE ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================================

-- Índices para la tabla warehouses
CREATE INDEX IF NOT EXISTS idx_warehouses_is_active ON warehouses(is_active);
CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name);

-- Índices para la tabla products
CREATE INDEX IF NOT EXISTS idx_products_warehouse_id ON products(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_quantity ON products(quantity);

-- Índices para la tabla inventory_movements
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_warehouse_id ON inventory_movements(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_user_id ON inventory_movements(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(type);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_date ON inventory_movements(movement_date);

-- Índices para la tabla sales
CREATE INDEX IF NOT EXISTS idx_sales_warehouse_id ON sales(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_payment_method ON sales(payment_method);

-- Índices para la tabla sale_items
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);

-- Índices para la tabla suppliers
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON suppliers(is_active);

-- ============================================================================
-- 3. CONFIGURACIÓN DE ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. POLÍTICAS DE SEGURIDAD RLS
-- ============================================================================

-- Políticas para warehouses
DROP POLICY IF EXISTS "Users can view warehouses" ON warehouses;
CREATE POLICY "Users can view warehouses" ON warehouses
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage warehouses" ON warehouses;
CREATE POLICY "Admins can manage warehouses" ON warehouses
    FOR ALL USING (
        auth.role() = 'authenticated' AND 
        (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin'
    );

-- Políticas para products (acceso completo para usuarios autenticados)
DROP POLICY IF EXISTS "Users can view products" ON products;
CREATE POLICY "Users can view products" ON products
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can manage products" ON products;
CREATE POLICY "Users can manage products" ON products
    FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para inventory_movements
DROP POLICY IF EXISTS "Users can view inventory movements" ON inventory_movements;
CREATE POLICY "Users can view inventory movements" ON inventory_movements
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can create inventory movements" ON inventory_movements;
CREATE POLICY "Users can create inventory movements" ON inventory_movements
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Políticas para sales
DROP POLICY IF EXISTS "Users can view their own sales" ON sales;
CREATE POLICY "Users can view their own sales" ON sales
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        (user_id = auth.uid() OR (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin')
    );

DROP POLICY IF EXISTS "Users can create sales" ON sales;
CREATE POLICY "Users can create sales" ON sales
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own sales" ON sales;
CREATE POLICY "Users can update their own sales" ON sales
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND 
        (user_id = auth.uid() OR (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin')
    );

-- Políticas para sale_items
DROP POLICY IF EXISTS "Users can view sale items" ON sale_items;
CREATE POLICY "Users can view sale items" ON sale_items
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM sales 
            WHERE sales.id = sale_items.sale_id 
            AND (sales.user_id = auth.uid() OR (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin')
        )
    );

DROP POLICY IF EXISTS "Users can manage sale items" ON sale_items;
CREATE POLICY "Users can manage sale items" ON sale_items
    FOR ALL USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM sales 
            WHERE sales.id = sale_items.sale_id 
            AND (sales.user_id = auth.uid() OR (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin')
        )
    );

-- Políticas para suppliers
DROP POLICY IF EXISTS "Users can view suppliers" ON suppliers;
CREATE POLICY "Users can view suppliers" ON suppliers
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage suppliers" ON suppliers;
CREATE POLICY "Admins can manage suppliers" ON suppliers
    FOR ALL USING (
        auth.role() = 'authenticated' AND 
        (auth.jwt() ->> 'user_metadata' ->> 'role') = 'admin'
    );

-- ============================================================================
-- 5. FUNCIONES RPC PARA GESTIÓN DE USUARIOS
-- ============================================================================

-- Eliminar funciones existentes si existen
DROP FUNCTION IF EXISTS public.get_auth_users_admin();
DROP FUNCTION IF EXISTS public.get_auth_users_simple();

-- Función RPC principal para obtener usuarios (solo administradores)
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

-- Función RPC alternativa que retorna JSON (por compatibilidad)
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

-- ============================================================================
-- 6. FUNCIONES PARA REPORTES Y ESTADÍSTICAS
-- ============================================================================

-- Función para obtener estadísticas de ventas por fecha
CREATE OR REPLACE FUNCTION public.get_sales_stats(
    start_date TIMESTAMPTZ DEFAULT NULL,
    end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    total_sales BIGINT,
    total_amount NUMERIC,
    average_sale NUMERIC,
    top_selling_products JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario está autenticado
    IF auth.role() != 'authenticated' THEN
        RAISE EXCEPTION 'Access denied. Authentication required.';
    END IF;

    -- Si no se proporcionan fechas, usar el mes actual
    IF start_date IS NULL THEN
        start_date := date_trunc('month', now());
    END IF;
    
    IF end_date IS NULL THEN
        end_date := date_trunc('month', now()) + interval '1 month' - interval '1 second';
    END IF;

    RETURN QUERY
    SELECT 
        COUNT(s.id)::BIGINT as total_sales,
        COALESCE(SUM(s.total_amount), 0) as total_amount,
        COALESCE(AVG(s.total_amount), 0) as average_sale,
        COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'product_name', p.name,
                    'total_quantity', SUM(si.quantity),
                    'total_revenue', SUM(si.total_price)
                )
            )
            FROM sale_items si
            JOIN products p ON si.product_id = p.id
            JOIN sales s2 ON si.sale_id = s2.id
            WHERE s2.sale_date >= start_date AND s2.sale_date <= end_date
            GROUP BY p.id, p.name
            ORDER BY SUM(si.quantity) DESC
            LIMIT 10), '[]'::json
        ) as top_selling_products
    FROM sales s
    WHERE s.sale_date >= start_date AND s.sale_date <= end_date;
END;
$$;

-- Función para obtener productos con stock bajo
CREATE OR REPLACE FUNCTION public.get_low_stock_products()
RETURNS TABLE (
    product_id TEXT,
    product_name TEXT,
    current_stock INTEGER,
    min_stock INTEGER,
    warehouse_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario está autenticado
    IF auth.role() != 'authenticated' THEN
        RAISE EXCEPTION 'Access denied. Authentication required.';
    END IF;

    RETURN QUERY
    SELECT 
        p.id as product_id,
        p.name as product_name,
        p.quantity as current_stock,
        p.min_stock,
        w.name as warehouse_name
    FROM products p
    JOIN warehouses w ON p.warehouse_id = w.id
    WHERE p.quantity <= p.min_stock 
    AND p.is_active = true
    ORDER BY (p.quantity::float / NULLIF(p.min_stock, 0)) ASC;
END;
$$;

-- ============================================================================
-- 7. TRIGGERS PARA AUDITORÍA Y SINCRONIZACIÓN
-- ============================================================================

-- Función para actualizar timestamp de updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para actualizar updated_at automáticamente
DROP TRIGGER IF EXISTS update_warehouses_updated_at ON warehouses;
CREATE TRIGGER update_warehouses_updated_at 
    BEFORE UPDATE ON warehouses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sales_updated_at ON sales;
CREATE TRIGGER update_sales_updated_at 
    BEFORE UPDATE ON sales 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_suppliers_updated_at ON suppliers;
CREATE TRIGGER update_suppliers_updated_at 
    BEFORE UPDATE ON suppliers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 8. COMENTARIOS EN TABLAS Y FUNCIONES
-- ============================================================================

COMMENT ON TABLE warehouses IS 'Tabla de almacenes/sucursales';
COMMENT ON TABLE products IS 'Tabla de productos del inventario';
COMMENT ON TABLE inventory_movements IS 'Registro de movimientos de inventario';
COMMENT ON TABLE sales IS 'Registro de ventas realizadas';
COMMENT ON TABLE sale_items IS 'Detalles de productos vendidos en cada venta';
COMMENT ON TABLE suppliers IS 'Tabla de proveedores';

COMMENT ON FUNCTION public.get_auth_users_admin() IS 'Función RPC para obtener usuarios de auth.users (solo administradores)';
COMMENT ON FUNCTION public.get_auth_users_simple() IS 'Función RPC alternativa que retorna usuarios como JSON (solo administradores)';
COMMENT ON FUNCTION public.get_sales_stats(TIMESTAMPTZ, TIMESTAMPTZ) IS 'Obtiene estadísticas de ventas para un período específico';
COMMENT ON FUNCTION public.get_low_stock_products() IS 'Obtiene productos con stock bajo o crítico';

-- ============================================================================
-- CONFIGURACIÓN COMPLETADA
-- ============================================================================

-- Este mensaje aparecerá cuando la configuración se complete exitosamente
DO $$
BEGIN
    RAISE NOTICE 'Configuración de Supabase completada exitosamente!';
    RAISE NOTICE '- Todas las tablas han sido creadas';
    RAISE NOTICE '- Índices de optimización aplicados';
    RAISE NOTICE '- Políticas RLS configuradas';
    RAISE NOTICE '- Funciones RPC para usuarios creadas';
    RAISE NOTICE '- Funciones de reportes disponibles';
    RAISE NOTICE '- Triggers de auditoría activados';
    RAISE NOTICE '';
    RAISE NOTICE 'La aplicación Flutter ya puede conectarse a esta base de datos.';
END $$;