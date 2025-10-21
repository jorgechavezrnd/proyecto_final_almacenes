# Sistema de Gestión de Almacenes 🏪

Una aplicación móvil completa desarrollada en **Flutter** para la gestión integral de almacenes e inventarios. La aplicación utiliza **Supabase** como backend y base de datos, **Drift** para persistencia local, y sigue la arquitectura **BLoC** para una gestión de estado robusta y escalable.

## 📋 Descripción del Proyecto

Este sistema permite a las empresas gestionar múltiples almacenes, controlar inventarios, realizar ventas y generar reportes detallados. La aplicación está diseñada para ser utilizada tanto por usuarios regulares como administradores, con diferentes niveles de acceso y funcionalidades.

### 🎯 Funcionalidades Principales

- **👥 Gestión de Usuarios**: Sistema de autenticación con roles (usuario/administrador)
- **🏢 Gestión de Almacenes**: Creación y administración de múltiples almacenes
- **📦 Control de Inventarios**: Gestión completa de productos, stock y movimientos
- **💰 Sistema de Ventas**: Registro de ventas con detalles de productos y clientes
- **📊 Reportes y Análisis**: Generación de reportes PDF con estadísticas de ventas
- **🔒 Seguridad**: Row Level Security (RLS) en base de datos
- **📱 Experiencia Móvil**: Diseño responsivo optimizado para dispositivos móviles
- **🌐 Sincronización**: Datos sincronizados en tiempo real con Supabase
- **📴 Offline-First**: Funcionalidad completa sin conexión a internet

## 🚀 Setup desde Cero

### Prerrequisitos

- **Flutter SDK** (versión 3.9.2 o superior)
- **Dart** (versión 3.0.0 o superior)
- **Cuenta en Supabase** (gratuita)
- **IDE**: VS Code, Android Studio o IntelliJ

### 1. 📥 Clonar y Configurar el Proyecto

```bash
# Clonar el repositorio
git clone <url-del-repositorio>
cd proyecto_final_almacenes

# Instalar dependencias
flutter pub get

# Generar código de Drift y otros archivos generados
dart run build_runner build
```

### 2. 🔧 Configurar Supabase

#### Paso 1: Crear Proyecto en Supabase
1. Ve a [https://supabase.com](https://supabase.com)
2. Crea una cuenta o inicia sesión
3. Crea un nuevo proyecto
4. Espera a que el proyecto se configure completamente

#### Paso 2: Obtener Credenciales
1. Ve a **Project Settings** → **API**
2. Copia el **Project URL** y la **anon/public key**

#### Paso 3: Configurar Variables de Entorno
1. **Copia el archivo de ejemplo**:
   ```bash
   # En la raíz del proyecto
   copy .env.example .env
   ```

2. **Edita el archivo `.env`** con tus credenciales reales:
   ```bash
   # .env - Reemplaza con tus credenciales de Supabase
   SUPABASE_URL=https://tu-proyecto-id.supabase.co
   SUPABASE_ANON_KEY=tu-clave-anon-real-aqui
   REDIRECT_URL=https://tu-app.com/auth/callback
   ```

### 3. 🗄️ Configurar Base de Datos

#### Ejecutar Script de Configuración
1. Ve al **SQL Editor** en tu dashboard de Supabase
2. Copia **TODO** el contenido del archivo `supabase_configuration.sql`
3. Pégalo en el editor SQL y ejecuta el script completo
4. Verifica que aparezcan mensajes de confirmación

> ⚠️ **Importante**: El archivo `supabase_configuration.sql` contiene toda la configuración necesaria: tablas, índices, políticas RLS y funciones.

### 4. ▶️ Ejecutar la Aplicación

```bash
# Para desarrollo
flutter run

# Para compilar APK de debug
flutter build apk --debug

# Para compilar APK de release
flutter build apk --release
```

## 🏗️ Arquitectura del Proyecto

### 📁 Estructura de Directorios
```
lib/
├── blocs/                     # 🧠 Gestión de Estado (BLoC Pattern)
│   ├── auth_bloc.dart         # Autenticación y sesiones
│   ├── auth_event.dart        # Eventos de autenticación
│   ├── auth_state.dart        # Estados de autenticación
│   ├── product_bloc.dart      # Gestión de productos
│   ├── reports_bloc.dart      # Reportes y estadísticas
│   ├── sales_bloc.dart        # Sistema de ventas
│   ├── users_bloc.dart        # Gestión de usuarios (admin)
│   └── warehouse_bloc.dart    # Gestión de almacenes
├── config/                    # ⚙️ Configuraciones
│   └── supabase_config.dart   # Credenciales de Supabase
├── database/                  # 💾 Base de Datos Local (Drift)
│   ├── database.dart          # Configuración principal
│   ├── database.g.dart        # Código generado
│   ├── sales_dao.dart         # DAO para ventas
│   └── user_session_dao.dart  # DAO para sesiones
├── models/                    # 🏗️ Modelos de Datos
│   ├── product_model.dart     # Modelo de productos
│   ├── sale_model.dart        # Modelo de ventas
│   ├── user_model.dart        # Modelo de usuarios
│   └── warehouse_model.dart   # Modelo de almacenes
├── repositories/              # 🔄 Capa de Datos
│   ├── auth_repository.dart   # Autenticación
│   └── inventory_repository.dart # Inventarios y ventas
├── screens/                   # 📱 Interfaz de Usuario
│   ├── dashboard_screen.dart  # Dashboard principal
│   ├── login_screen.dart      # Pantalla de login
│   ├── signup_screen.dart     # Pantalla de registro
│   ├── products_screen.dart   # Gestión de productos
│   ├── warehouse_list_screen.dart # Lista de almacenes
│   ├── sales/                 # Módulo de ventas
│   │   ├── sales_screen.dart
│   │   └── sale_form_screen.dart
│   ├── reports/               # Módulo de reportes
│   │   ├── reports_screen.dart
│   │   └── admin_reports_screen.dart
│   └── users/                 # Gestión de usuarios (admin)
│       └── users_screen.dart
├── services/                  # 🌐 Servicios Externos
│   ├── supabase_service.dart  # Cliente Supabase
│   └── pdf_report_service.dart # Generación de PDFs
└── main.dart                  # 🚀 Punto de entrada
```

### 🎨 Patrones de Arquitectura

#### **BLoC Pattern (Business Logic Component)**
- **Separación de responsabilidades**: UI, lógica de negocio y datos están claramente separados
- **Gestión de estado reactiva**: Uso de Streams para actualizaciones en tiempo real
- **Testabilidad**: Cada BLoC puede ser probado independientemente

#### **Repository Pattern**
- **Abstracción de datos**: Los BLoCs no conocen la fuente de datos específica
- **Flexibilidad**: Fácil cambio entre diferentes fuentes de datos
- **Cacheo**: Implementación de caché local con Drift

#### **DAO Pattern (Data Access Object)**
- **Operaciones de base de datos**: Encapsulación de consultas SQL complejas
- **Optimización**: Consultas optimizadas para rendimiento
- **Mantenibilidad**: Fácil modificación de esquemas de datos

### 🔧 Stack Tecnológico

#### **Frontend (Flutter)**
- **Material Design 3**: UI moderna y consistente
- **BLoC 8.1.4**: Gestión de estado robusta
- **Localización**: Soporte para español
- **PDF Generation**: Reportes en formato PDF

#### **Backend (Supabase)**
- **PostgreSQL**: Base de datos relacional potente
- **Row Level Security**: Seguridad a nivel de fila
- **Real-time subscriptions**: Actualizaciones en tiempo real
- **Edge Functions**: Funciones serverless (si se requieren)

#### **Persistencia Local (Drift)**
- **SQLite**: Base de datos local embebida
- **Type-safe queries**: Consultas SQL con verificación de tipos
- **Migrations**: Sistema de migraciones automático
- **Cache inteligente**: Optimización de acceso a datos

### 🔐 Seguridad Implementada

#### **Autenticación y Autorización**
- **JWT Tokens**: Autenticación basada en tokens seguros
- **Role-based Access**: Control de acceso basado en roles
- **Session Management**: Gestión segura de sesiones

#### **Row Level Security (RLS)**
- **Políticas granulares**: Acceso controlado a nivel de registro
- **Aislamiento de datos**: Los usuarios solo ven sus propios datos
- **Administradores**: Acceso completo con verificación de rol

### 📊 Funcionalidades por Módulo

#### **👤 Módulo de Autenticación**
- Login/Registro con email y contraseña
- Gestión de sesiones persistentes
- Control de roles (usuario/administrador)

#### **🏢 Módulo de Almacenes**
- Crear y editar almacenes
- Listar almacenes activos
- Asignación de productos por almacén

#### **📦 Módulo de Productos**
- CRUD completo de productos
- Control de stock y niveles mínimos
- Categorización de productos
- Códigos SKU y códigos de barras

#### **💰 Módulo de Ventas**
- Crear ventas con múltiples productos
- Cálculo automático de totales e impuestos
- Diferentes métodos de pago
- Historial de ventas por usuario

#### **📈 Módulo de Reportes**
- Reportes de ventas por período
- Estadísticas de productos más vendidos
- Reportes administrativos (todos los usuarios)
- Exportación a PDF con gráficos

#### **👥 Módulo de Usuarios (Solo Admin)**
- Listar todos los usuarios registrados
- Ver información de acceso y roles
- Gestión de permisos

## 🔄 Flujo de Datos

### 1. **UI → BLoC → Repository → Service/DAO**
```
User Action → UI Event → BLoC Event → Repository Method → 
Supabase/Drift Operation → Data Response → BLoC State → UI Update
```

### 2. **Sincronización de Datos**
- **Writes**: Supabase primero, luego caché local
- **Reads**: Caché local primero, respaldo con Supabase
- **Conflicts**: Supabase tiene prioridad (source of truth)

### 3. **Gestión de Estados**
- **Loading**: Durante operaciones asíncronas
- **Success**: Operación completada exitosamente
- **Error**: Manejo graceful de errores con mensajes de usuario

## 🎯 Casos de Uso Principales

### **Usuario Regular**
1. **Login** → **Dashboard** → **Seleccionar Almacén**
2. **Gestionar Productos** → **Realizar Ventas** → **Ver Reportes**
3. **Actualizar Inventario** → **Generar PDF** → **Logout**

### **Administrador**
1. **Login** → **Dashboard Admin** → **Gestionar Usuarios**
2. **Ver Todos los Almacenes** → **Reportes Consolidados**
3. **Administrar Sistema** → **Supervisar Operaciones**

### **Comandos Útiles de Desarrollo**

```bash
# Configurar variables de entorno (primera vez)
copy .env.example .env
# Luego edita .env con tus credenciales reales

# Instalar dependencias
flutter pub get

# Generar código de Drift cuando cambies esquemas
dart run build_runner build

# Limpiar y regenerar archivos
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs

# Ejecutar análisis de código
flutter analyze

# Formatear código
dart format lib/

# Ejecutar en modo debug con hot reload
flutter run

# Compilar para release
flutter build apk --release
```

### **Estructura de Base de Datos**

El archivo `supabase_configuration.sql` incluye:
- **8 tablas principales** con relaciones optimizadas
- **15+ índices** para consultas rápidas
- **Políticas RLS** para seguridad granular
- **4 funciones RPC** para operaciones avanzadas
- **Triggers de auditoría** automáticos


