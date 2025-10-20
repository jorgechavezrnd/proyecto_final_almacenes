import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../blocs/reports_bloc.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/auth_repository.dart';
import 'login_screen.dart';
import 'warehouse_list_screen.dart';
import 'sales/sales_screen.dart';
import 'reports/reports_screen.dart';
import 'reports/admin_reports_screen.dart';
import 'users/users_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthUnauthenticated) {
          // Navigate to login screen when logged out
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout(context);
                } else if (value == 'profile') {
                  _showProfileDialog(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 8),
                      Text('Perfil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Cerrar Sesión'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: BlocBuilder<AuthBloc, auth_states.AuthState>(
          builder: (context, state) {
            if (state is auth_states.AuthAuthenticated) {
              return _buildDashboardContent(context, state.user, state.role);
            } else if (state is auth_states.AuthLoading) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return const Center(child: Text('Error loading dashboard'));
            }
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, User user, String? role) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.userMetadata?['full_name'] ??
                        user.email?.split('@').first ??
                        'Usuario',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        user.email ?? '',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (role != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Rol: ${role.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Acciones Rápidas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Action Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: _buildActionCards(context, role),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionCards(BuildContext context, String? role) {
    // Acciones básicas para todos los usuarios
    List<Widget> actions = [
      _buildActionCard(
        title: 'Almacenes',
        icon: Icons.warehouse,
        color: Colors.blue,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WarehouseListScreen(userRole: role),
            ),
          );
        },
      ),
    ];

    // Acciones adicionales para administradores
    if (role?.toLowerCase() == 'admin') {
      actions.addAll([
        _buildActionCard(
          title: 'Usuarios',
          icon: Icons.people,
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UsersScreen()),
            );
          },
        ),
        _buildActionCard(
          title: 'Reportes Admin',
          icon: Icons.analytics,
          color: Colors.red,
          onTap: () async {
            try {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) {
                      print('Creating ReportsBloc for AdminReportsScreen...');
                      return ReportsBloc(
                        repository: InventoryRepository.instance,
                        authRepository: AuthRepository.instance,
                      );
                    },
                    child: const AdminReportsScreen(),
                  ),
                ),
              );
            } catch (e) {
              print('Error navigating to admin reports: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ]);
    } else {
      // Acciones para usuarios regulares
      actions.addAll([
        _buildActionCard(
          title: 'Ventas',
          icon: Icons.point_of_sale,
          color: Colors.indigo,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SalesScreen()),
            );
          },
        ),
        _buildActionCard(
          title: 'Movimientos',
          icon: Icons.swap_horiz,
          color: Colors.orange,
          onTap: () {
            _showComingSoon(context, 'Movimientos');
          },
        ),
        _buildActionCard(
          title: 'Reportes',
          icon: Icons.bar_chart,
          color: Colors.purple,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BlocProvider(
                  create: (context) => ReportsBloc(
                    repository: InventoryRepository.instance,
                    authRepository: AuthRepository.instance,
                  ),
                  child: const ReportsScreen(),
                ),
              ),
            );
          },
        ),
      ]);
    }

    return actions;
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final authBloc = context.read<AuthBloc>();

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<User?>(
        future: authBloc.getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) return const SizedBox();

          return AlertDialog(
            title: const Text('Perfil de Usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileRow(
                  'Nombre:',
                  user.userMetadata?['full_name'] ?? 'N/A',
                ),
                _buildProfileRow('Email:', user.email ?? 'N/A'),
                _buildProfileRow('ID:', user.id),
                FutureBuilder<String?>(
                  future: authBloc.getUserRole(),
                  builder: (context, roleSnapshot) {
                    return _buildProfileRow(
                      'Rol:',
                      roleSnapshot.data?.toUpperCase() ?? 'N/A',
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.orange),
            SizedBox(width: 8),
            Text('Próximamente'),
          ],
        ),
        content: Text(
          'La funcionalidad "$feature" estará disponible próximamente.\n\n'
          'Esta es una versión demo del sistema de autenticación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
