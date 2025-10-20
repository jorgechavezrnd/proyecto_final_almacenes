import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/sales_bloc.dart';
import '../../database/database.dart' as db;
import '../../repositories/inventory_repository.dart';
import 'sale_form_screen.dart';

/// Screen for displaying and managing sales
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWarehouse;
  List<db.Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    context.read<SalesBloc>().add(LoadSales());
    _loadWarehouses();
  }

  void _loadWarehouses() async {
    // Load warehouses from repository - simplified for now
    // In a full implementation, this would come from a warehouse bloc
    setState(() {
      _warehouses = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              context.read<SalesBloc>().add(const SyncSales());
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocListener<SalesBloc, SalesState>(
        listener: (context, state) {
          if (state is SalesSync) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: BlocBuilder<SalesBloc, SalesState>(
                builder: (context, state) {
                  if (state is SalesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is SalesError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar las ventas',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInitialData,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is SalesLoaded) {
                    if (state.sales.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildSalesList(state.sales);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewSale,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar ventas',
                hintText: 'Nombre del cliente, ID de venta...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Implement search filter
                _applyFilters();
              },
            ),
            if (_startDate != null ||
                _endDate != null ||
                _selectedWarehouse != null)
              const SizedBox(height: 12),
            if (_startDate != null ||
                _endDate != null ||
                _selectedWarehouse != null)
              _buildActiveFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      children: [
        if (_startDate != null)
          Chip(
            label: Text(
              'Desde: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
            ),
            onDeleted: () {
              setState(() {
                _startDate = null;
              });
              _applyFilters();
            },
          ),
        if (_endDate != null)
          Chip(
            label: Text('Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
            onDeleted: () {
              setState(() {
                _endDate = null;
              });
              _applyFilters();
            },
          ),
        if (_selectedWarehouse != null)
          Chip(
            label: Text('Almacén: $_selectedWarehouse'),
            onDeleted: () {
              setState(() {
                _selectedWarehouse = null;
              });
              _applyFilters();
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay ventas registradas',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera venta tocando el botón +',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList(List<db.Sale> sales) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(db.Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(sale.status),
          child: Text(
            sale.totalAmount.toString().substring(0, 1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sale.customerName ?? 'Cliente General',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(sale.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(sale.status),
                  width: 1,
                ),
              ),
              child: Text(
                _getStatusText(sale.status),
                style: TextStyle(
                  color: _getStatusColor(sale.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${sale.id.substring(0, 8)}...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  sale.paymentMethod,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '\$${sale.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showSaleDetails(sale),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleSaleAction(action, sale),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('Ver detalles'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completada';
      case 'pending':
        return 'Pendiente';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Desconocido';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar ventas'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Fecha de inicio'),
                subtitle: Text(
                  _startDate != null
                      ? DateFormat('dd/MM/yyyy').format(_startDate!)
                      : 'No seleccionada',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() {
                      _startDate = date;
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Fecha de fin'),
                subtitle: Text(
                  _endDate != null
                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                      : 'No seleccionada',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
              if (_warehouses.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedWarehouse,
                  decoration: const InputDecoration(labelText: 'Almacén'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los almacenes'),
                    ),
                    ..._warehouses.map(
                      (warehouse) => DropdownMenuItem(
                        value: warehouse.id,
                        child: Text(warehouse.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedWarehouse = value;
                    });
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _selectedWarehouse = null;
              });
              Navigator.of(context).pop();
              _applyFilters();
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _applyFilters();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    if (_startDate != null && _endDate != null) {
      context.read<SalesBloc>().add(
        LoadSalesByDateRange(startDate: _startDate!, endDate: _endDate!),
      );
    } else if (_selectedWarehouse != null) {
      context.read<SalesBloc>().add(LoadSalesByWarehouse(_selectedWarehouse!));
    } else {
      context.read<SalesBloc>().add(LoadSales());
    }
  }

  void _navigateToNewSale() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SaleFormScreen()));

    if (result == true) {
      // Reload sales after creating a new one
      context.read<SalesBloc>().add(LoadSales());
    }
  }

  void _showSaleDetails(db.Sale sale) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SalesBloc>(),
        child: _SaleDetailsDialog(saleId: sale.id),
      ),
    );
  }

  void _handleSaleAction(String action, db.Sale sale) {
    if (action == 'view') {
      _showSaleDetails(sale);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Separate dialog widget for showing sale details
class _SaleDetailsDialog extends StatefulWidget {
  final String saleId;

  const _SaleDetailsDialog({required this.saleId});

  @override
  State<_SaleDetailsDialog> createState() => _SaleDetailsDialogState();
}

class _SaleDetailsDialogState extends State<_SaleDetailsDialog> {
  Map<String, dynamic>? saleWithItems;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSaleDetails();
  }

  Future<void> _loadSaleDetails() async {
    try {
      // Create a temporary repository instance to get sale details
      final repository = InventoryRepository.instance;
      final details = await repository.getSaleWithItems(widget.saleId);
      if (mounted) {
        setState(() {
          saleWithItems = details;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Error loading sale details: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AlertDialog(
        content: SizedBox(
          width: 200,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (error != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    if (saleWithItems == null || saleWithItems!.isEmpty) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('No se encontraron detalles de la venta'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    return _buildSaleDetailsContent(saleWithItems!);
  }

  Widget _buildSaleDetailsContent(Map<String, dynamic> saleWithItems) {
    final sale = saleWithItems['sale'] as db.Sale;
    final items = saleWithItems['items'] as List<Map<String, dynamic>>;

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Detalle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // Sale information
            Text('ID: ${sale.id.substring(0, 8)}...'),
            Text('Cliente: ${sale.customerName ?? 'Cliente General'}'),
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate)}',
            ),
            Text('Método de pago: ${sale.paymentMethod}'),
            const SizedBox(height: 16),
            Text('Productos:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Items list
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final itemData = items[index];
                  final item = itemData['item'] as db.SaleItem;
                  final product = itemData['product'] as db.Product?;

                  return ListTile(
                    title: Text(product?.name ?? 'Producto'),
                    subtitle: Text(
                      'Cantidad: ${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
                    ),
                    trailing: Text('\$${item.totalPrice.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const Divider(),
            // Totals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('\$${sale.subtotal.toStringAsFixed(2)}'),
              ],
            ),
            if (sale.taxAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Impuestos:'),
                  Text('\$${sale.taxAmount.toStringAsFixed(2)}'),
                ],
              ),
            if (sale.discountAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descuento:'),
                  Text('-\$${sale.discountAmount.toStringAsFixed(2)}'),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '\$${sale.totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
