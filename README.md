# Sistema de Almacenes - Flutter App

Una aplicación Flutter que utiliza Supabase para autenticación y Drift para persistencia local.

## Características

- ✅ Autenticación con email/contraseña usando Supabase
- ✅ Gestión de sesiones y detección de roles de usuario
- ✅ Caché local de sesión de usuario en Drift
- ✅ Integración con arquitectura BLoC
- ✅ Pantalla de login y registro
- ✅ Dashboard con información del usuario

## Configuración

### 1. Configurar Supabase

1. Ve a [https://supabase.com](https://supabase.com) y crea un nuevo proyecto
2. Ve a Project Settings > API
3. Copia el Project URL y la anon/public key
4. Actualiza `lib/config/supabase_config.dart` con tus credenciales:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'TU_URL_DE_SUPABASE';
  static const String supabaseAnonKey = 'TU_CLAVE_ANON_DE_SUPABASE';
}
```

### 2. Configurar Autenticación en Supabase

1. Ve a Authentication > Settings en el dashboard de Supabase
2. Habilita el proveedor de Email
3. Configura las plantillas de email si es necesario

### 3. (Opcional) Crear tabla de roles de usuario

```sql
CREATE TABLE user_roles (
  id UUID REFERENCES auth.users ON DELETE CASCADE,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (id)
);
```

### 4. Instalar dependencias

```bash
flutter pub get
```

### 5. Generar código de Drift

```bash
dart run build_runner build
```

### 6. Ejecutar la aplicación

```bash
flutter run
```

## Estructura del Proyecto

```
lib/
├── bloc/                   # BLoC para gestión de estado
│   ├── auth_bloc.dart
│   ├── auth_event.dart
│   └── auth_state.dart
├── config/                 # Configuraciones
│   └── supabase_config.dart
├── database/               # Base de datos local Drift
│   ├── database.dart
│   ├── database.g.dart     # Generado automáticamente
│   └── user_session_dao.dart
├── repositories/           # Repositorios para abstracción de datos
│   └── auth_repository.dart
├── screens/                # Pantallas de la UI
│   ├── dashboard_screen.dart
│   ├── login_screen.dart
│   └── signup_screen.dart
├── services/               # Servicios externos
│   └── supabase_service.dart
└── main.dart              # Punto de entrada
```

## Flujo de Autenticación

1. **Inicialización**: La app verifica si hay una sesión válida guardada localmente
2. **Login/Registro**: Usuario se autentica usando email/contraseña
3. **Gestión de Sesión**: La sesión se guarda tanto en Supabase como localmente en Drift
4. **Persistencia**: La sesión persiste entre reinicios de la app
5. **Logout**: Se limpia la sesión tanto remota como local

## Clases Principales

### SupabaseService
- Maneja todas las operaciones de autenticación con Supabase
- Login, registro, logout, reset de contraseña
- Gestión de errores y validaciones

### AuthRepository
- Abstrae la lógica de Supabase + Drift
- Coordina el almacenamiento local y remoto
- Proporciona una interfaz unificada para el BLoC

### AuthBloc
- Gestiona el estado de autenticación de la aplicación
- Maneja eventos de login, logout, registro
- Proporciona estados reactivos para la UI

### UserSessionDao
- Maneja operaciones de base de datos local con Drift
- Almacena y recupera sesiones de usuario
- Limpia sesiones expiradas

## Uso

### Login
```dart
context.read<AuthBloc>().add(
  AuthLoginRequested(
    email: 'usuario@ejemplo.com',
    password: 'contraseña123',
  ),
);
```

### Registro
```dart
context.read<AuthBloc>().add(
  AuthSignUpRequested(
    email: 'nuevo@ejemplo.com',
    password: 'contraseña123',
    metadata: {'full_name': 'Nombre Completo'},
  ),
);
```

### Logout
```dart
context.read<AuthBloc>().add(const AuthLogoutRequested());
```

## Próximos Pasos

- [ ] Implementar módulos de inventario
- [ ] Agregar gestión de productos
- [ ] Crear sistema de movimientos
- [ ] Desarrollar reportes y analytics
- [ ] Implementar notificaciones push
- [ ] Agregar soporte offline
