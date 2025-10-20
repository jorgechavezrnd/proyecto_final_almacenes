import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/warehouse_bloc.dart';
import '../database/database.dart';
import 'warehouse_form_screen.dart';
import 'products_screen.dart';

class WarehouseListScreen extends StatefulWidget {
  final String? userRole;

  const WarehouseListScreen({super.key, this.userRole});

  @override
  State<WarehouseListScreen> createState() => _WarehouseListScreenState();
}

class _WarehouseListScreenState extends State<WarehouseListScreen> {
  bool get isAdmin => widget.userRole?.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    context.read<WarehouseBloc>().add(const LoadWarehouses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Almacenes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          BlocBuilder<WarehouseBloc, WarehouseState>(
            builder: (context, state) {
              if (state is WarehouseLoaded && state.hasPendingSync) {
                return IconButton(
                  icon: const Icon(Icons.sync, color: Colors.orange),
                  onPressed: () {
                    context.read<WarehouseBloc>().add(const SyncWarehouses());
                  },
                  tooltip: 'Sincronizar cambios pendientes',
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<WarehouseBloc>().add(const RefreshWarehouses());
                },
                tooltip: 'Actualizar',
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<WarehouseBloc, WarehouseState>(
        listener: (context, state) {
          if (state is WarehouseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is WarehouseOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is WarehouseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WarehouseError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar almacenes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<WarehouseBloc>().add(const LoadWarehouses());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          List<Warehouse> warehouses = [];
          bool hasPendingSync = false;
          bool isSyncing = false;

          if (state is WarehouseLoaded) {
            warehouses = state.warehouses;
            hasPendingSync = state.hasPendingSync;
          } else if (state is WarehouseOperationSuccess) {
            warehouses = state.warehouses;
          } else if (state is WarehouseSyncing) {
            warehouses = state.warehouses;
            isSyncing = true;
          }

          if (warehouses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay almacenes registrados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Crea tu primer almacén para comenzar'
                        : 'No hay almacenes registrados',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToCreateWarehouse(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear Almacén'),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              if (isSyncing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sincronizando con el servidor...',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              if (hasPendingSync && !isSyncing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[50],
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_problem,
                        color: Colors.orange[700],
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hay cambios pendientes de sincronizar',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<WarehouseBloc>().add(
                            const SyncWarehouses(),
                          );
                        },
                        child: const Text('Sincronizar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context.read<WarehouseBloc>().add(
                      const RefreshWarehouses(),
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: warehouses.length,
                    itemBuilder: (context, index) {
                      final warehouse = warehouses[index];
                      return _WarehouseCard(
                        warehouse: warehouse,
                        isAdmin: isAdmin,
                        onTap: () => _navigateToProducts(context, warehouse),
                        onEdit: () =>
                            _navigateToEditWarehouse(context, warehouse),
                        onDelete: () =>
                            _showDeleteConfirmation(context, warehouse),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToCreateWarehouse(context),
              tooltip: 'Crear Almacén',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _navigateToCreateWarehouse(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WarehouseFormScreen()),
    );
  }

  void _navigateToEditWarehouse(BuildContext context, Warehouse warehouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WarehouseFormScreen(warehouse: warehouse),
      ),
    );
  }

  void _navigateToProducts(BuildContext context, Warehouse warehouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ProductsScreen(warehouse: warehouse, userRole: widget.userRole),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Warehouse warehouse) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Almacén'),
          content: Text(
            '¿Estás seguro de que deseas eliminar el almacén "${warehouse.name}"?\n\n'
            'Esta acción desactivará el almacén y todos sus productos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<WarehouseBloc>().add(
                  DeleteWarehouse(warehouse.id),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WarehouseCard({
    required this.warehouse,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: warehouse.isActive
                          ? Colors.green[100]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warehouse,
                      color: warehouse.isActive
                          ? Colors.green[700]
                          : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warehouse.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: warehouse.isActive
                                    ? null
                                    : Colors.grey[600],
                              ),
                        ),
                        if (warehouse.description != null &&
                            warehouse.description!.isNotEmpty)
                          Text(
                            warehouse.description!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (warehouse.address != null &&
                  warehouse.address!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warehouse.address!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (warehouse.city != null && warehouse.city!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_city,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      warehouse.city!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              if (warehouse.phone != null && warehouse.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      warehouse.phone!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: warehouse.isActive
                          ? Colors.green[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      warehouse.isActive ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: warehouse.isActive
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
