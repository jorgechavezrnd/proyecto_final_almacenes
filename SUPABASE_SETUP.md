# Configuración de Base de Datos Supabase

## 📋 Instrucciones para Configurar las Tablas

### 1. Acceder al Panel de Supabase
1. Ve a [https://supabase.com](https://supabase.com)
2. Inicia sesión en tu cuenta
3. Selecciona tu proyecto

### 2. Ejecutar Migration Script (IMPORTANTE)
**Como las tablas ya existen, usa el archivo de migración:**

1. En el panel izquierdo, haz clic en **"SQL Editor"**
2. Haz clic en **"New Query"**
3. Copia y pega el contenido completo del archivo `migration_remove_manager.sql`
4. Haz clic en **"Run"** para ejecutar la migración

**⚠️ NO ejecutes `supabase_tables.sql` - usa solo `migration_remove_manager.sql`**

### 3. Verificar la Creación de Tablas
1. Ve a **"Table Editor"** en el panel izquierdo
2. Deberías ver las siguientes tablas creadas:
   - `warehouses` (almacenes)
   - `products` (productos)
   - `inventory_movements` (movimientos de inventario)

### 4. Configurar Row Level Security (RLS)
Los scripts incluyen configuración básica de RLS que:
- ✅ Permite a todos los usuarios autenticados **leer** datos
- ✅ Solo permite a **administradores** crear/editar/eliminar almacenes y productos
- ✅ Permite a usuarios autenticados crear movimientos de inventario

### 5. Probar la Sincronización
1. En tu aplicación Flutter, inicia sesión como administrador
2. Crea algunos almacenes y productos
3. Haz clic en el botón de **sincronización** (🔄)
4. Verifica en Supabase que los datos aparezcan en las tablas

## 🔧 Estructura de Tablas Creadas

### Warehouses (Almacenes)
```sql
- id: TEXT (Primary Key)
- name: TEXT (Nombre del almacén)
- description: TEXT (Descripción opcional)
- address: TEXT (Dirección)
- city: TEXT (Ciudad)
- phone: TEXT (Teléfono)
- email: TEXT (Email)
- is_active: BOOLEAN (Estado activo/inactivo)
- created_at: TIMESTAMPTZ (Fecha de creación)
- updated_at: TIMESTAMPTZ (Fecha de actualización)
- last_sync_at: TIMESTAMPTZ (Última sincronización)
```

### Products (Productos)
```sql
- id: TEXT (Primary Key)
- warehouse_id: TEXT (FK a warehouses)
- name: TEXT (Nombre del producto)
- description: TEXT (Descripción opcional)
- sku: TEXT (Código SKU único)
- barcode: TEXT (Código de barras)
- category: TEXT (Categoría)
- price: DECIMAL (Precio de venta)
- cost: DECIMAL (Costo)
- quantity: INTEGER (Cantidad en stock)
- min_stock: INTEGER (Stock mínimo)
- max_stock: INTEGER (Stock máximo)
- unit: TEXT (Unidad de medida)
- is_active: BOOLEAN (Estado activo/inactivo)
- created_at: TIMESTAMPTZ (Fecha de creación)
- updated_at: TIMESTAMPTZ (Fecha de actualización)
- last_sync_at: TIMESTAMPTZ (Última sincronización)
```

### Inventory_Movements (Movimientos de Inventario)
```sql
- id: TEXT (Primary Key)
- product_id: TEXT (FK a products)
- warehouse_id: TEXT (FK a warehouses)
- user_id: TEXT (FK a auth.users)
- type: TEXT (Tipo: 'in', 'out', 'adjustment', 'transfer')
- quantity: INTEGER (Cantidad del movimiento)
- previous_stock: INTEGER (Stock anterior)
- new_stock: INTEGER (Stock nuevo)
- reason: TEXT (Razón del movimiento)
- reference_number: TEXT (Número de referencia)
- notes: TEXT (Notas adicionales)
- created_at: TIMESTAMPTZ (Fecha de creación)
- updated_at: TIMESTAMPTZ (Fecha de actualización)
```

## 🚨 Solución de Problemas

### Error: "Could not find the table public.warehouses"
Este error indica que las tablas no existen en Supabase. Para solucionarlo:

1. **Verificar que ejecutaste los scripts SQL completos**
2. **Revisar que las tablas aparezcan en Table Editor**
3. **Confirmar que los nombres de las tablas coincidan exactamente**

### Error: "Permission denied for table warehouses"
Esto indica problemas con Row Level Security:

1. **Verificar que tu usuario tenga el rol correcto en `user_metadata`**
2. **Revisar las políticas de RLS en la pestaña "Authentication" > "Policies"**
3. **Confirmar que las políticas permitan las operaciones necesarias**

### Verificar Configuración de Usuario Admin
Para que un usuario sea administrador, debe tener en su `user_metadata`:
```json
{
  "role": "admin"
}
```

Esto se puede configurar desde:
1. **Authentication** > **Users**
2. Hacer clic en un usuario
3. Editar **Raw User Meta Data**
4. Agregar: `{"role": "admin"}`

---

## 📧 Configuración de URLs de Redirección (Solo si hay problemas de email)

### 1. Acceder a la configuración de Supabase
1. Ve a [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Authentication** > **URL Configuration**

### 2. Configurar Site URL
- **Site URL**: `https://tu-dominio.com` (o `http://localhost:3000` para desarrollo local)

### 3. Configurar Redirect URLs
Agrega las siguientes URLs en la sección **Redirect URLs**:

Para desarrollo local:
```
http://localhost:3000/auth/callback
http://localhost:8080/auth/callback
http://127.0.0.1:3000/auth/callback
```

Para aplicaciones móviles Flutter:
```
io.supabase.flutterquickstart://login-callback/
tu.paquete.de.app://login-callback/
```

### 4. Alternativa: Deshabilitar confirmación de email (solo para desarrollo)
Si estás en desarrollo y quieres omitir la confirmación de email temporalmente:

1. Ve a **Authentication** > **Settings**
2. Desactiva **Enable email confirmations**

⚠️ **Advertencia**: No recomendado para producción por seguridad.

### 6. Para aplicaciones móviles Flutter
Si planeas usar esta app principalmente en móvil, puedes configurar:

1. En **Authentication** > **Settings**
2. Desactiva **Enable email confirmations** temporalmente
3. O configura deep links apropiados para tu app móvil

## Configuración actual del proyecto

Tu configuración actual en `supabase_config.dart`:
- URL: `https://hdjsoucuqegosvasovla.supabase.co`
- Esta configuración funcionará una vez que configures las URLs de redirección correctamente.

## Verificación
Después de hacer estos cambios:
1. El registro seguirá enviando un email de confirmación
2. Pero ahora el enlace en el email apuntará a la URL correcta
3. La app manejará correctamente el flujo de confirmación

## Notas adicionales
- Los cambios en la configuración de URLs pueden tardar unos minutos en aplicarse
- Si sigues teniendo problemas, verifica que no tengas caché en el navegador
- Para desarrollo local, asegúrate de que tu servidor local esté corriendo en el puerto configurado