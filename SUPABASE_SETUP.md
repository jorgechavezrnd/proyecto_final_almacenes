# Configuración de URLs de Redirección en Supabase

Para solucionar el problema de las URLs que apuntan a localhost:3000, necesitas configurar las URLs de redirección correctas en tu proyecto de Supabase.

## Pasos para configurar las URLs:

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

Para producción:
```
https://tu-dominio.com/auth/callback
https://tu-app.vercel.app/auth/callback
```

Para aplicaciones móviles Flutter:
```
io.supabase.flutterquickstart://login-callback/
tu.paquete.de.app://login-callback/
```

### 4. Configurar Email Templates (Opcional pero recomendado)
1. Ve a **Authentication** > **Email Templates**
2. Para **Confirm signup**, cambia la URL de:
   ```
   {{ .ConfirmationURL }}
   ```
   a:
   ```
   https://tu-dominio.com/auth/confirm?token={{ .Token }}&type=signup&redirect_to=https://tu-dominio.com/dashboard
   ```

### 5. Alternativa: Deshabilitar confirmación de email (solo para desarrollo)
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