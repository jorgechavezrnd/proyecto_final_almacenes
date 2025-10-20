# 🚨 Solución al Error: "relation warehouses already exists"

## ❌ **Error Recibido:**
```
ERROR: 42P07: relation "warehouses" already exists
```

## ✅ **Solución:**

### 1. **NO ejecutes `supabase_tables.sql`**
Las tablas ya existen en tu base de datos, por eso sale el error.

### 2. **Ejecuta el script de migración**
1. Ve a Supabase SQL Editor
2. Abre una nueva query
3. **Copia y pega SOLO el contenido de `migration_remove_manager.sql`**
4. Haz clic en "Run"

### 3. **¿Qué hace la migración?**
- ✅ Elimina funciones RPC innecesarias (`get_users_list`, `get_user_by_id`)
- ✅ Elimina el campo `manager_id` de la tabla `warehouses` 
- ✅ Mantiene todas las demás tablas y políticas intactas

### 4. **Después de la migración**
Tu tabla `warehouses` tendrá este esquema limpio:
```sql
- id (TEXT)
- name (TEXT) 
- description (TEXT)
- address (TEXT)
- city (TEXT)
- phone (TEXT)
- email (TEXT)
- is_active (BOOLEAN)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)  
- last_sync_at (TIMESTAMPTZ)
```

## 🎯 **Resultado Final:**
- ✅ Sistema simplificado sin gerentes por almacén
- ✅ Solo usuarios ADMIN pueden crear/editar almacenes
- ✅ Usuarios regulares solo pueden ver
- ✅ Sincronización funcionando correctamente

La migración es **segura** y **no afecta** los datos existentes, solo elimina el campo innecesario.