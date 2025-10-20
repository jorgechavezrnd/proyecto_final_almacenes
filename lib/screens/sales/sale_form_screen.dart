import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/sales_bloc.dart';
import '../../blocs/auth_bloc.dart';
import '../../blocs/auth_state.dart';
import '../../database/database.dart';
import '../../repositories/inventory_repository.dart';

/// Screen for creating new sales
class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Product> _availableProducts = [];
  List<SaleItem> _saleItems = [];

  String? _selectedWarehouseId;
  String _paymentMethod = 'cash';
  double _taxRate = 0.0;
  double _discountAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    try {
      final warehouses = await InventoryRepository.instance.getAllWarehouses();
      setState(() {
        _warehouses = warehouses;
        if (warehouses.isNotEmpty) {
          _selectedWarehouseId = warehouses.first.id;
          _loadProducts();
        }
      });
    } catch (e) {
      _showError('Error al cargar almacenes: $e');
    }
  }

  void _loadProducts() async {
    if (_selectedWarehouseId == null) return;

    try {
      final products = await InventoryRepository.instance
          .getProductsByWarehouse(_selectedWarehouseId!);
      setState(() {
        _availableProducts = products.where((p) => p.quantity > 0).toList();
      });
    } catch (e) {
      _showError('Error al cargar productos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        actions: [
          TextButton(
            onPressed: _saleItems.isNotEmpty ? _saveSale : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: BlocListener<SalesBloc, SalesState>(
        listener: (context, state) {
          if (state is SalesOperationSuccess) {
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Venta creada exitosamente')),
            );
          } else if (state is SalesError) {
            _showError(state.message);
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWarehouseSelection(),
                const SizedBox(height: 16),
                _buildCustomerSection(),
                const SizedBox(height: 16),
                _buildProductSelection(),
                const SizedBox(height: 16),
                _buildSaleItemsList(),
                const SizedBox(height: 16),
                _buildPaymentSection(),
                const SizedBox(height: 16),
                _buildSummarySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Almacén', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedWarehouseId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar almacén',
                border: OutlineInputBorder(),
              ),
              items: _warehouses
                  .map(
                    (warehouse) => DropdownMenuItem(
                      value: warehouse.id,
                      child: Text(warehouse.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWarehouseId = value;
                  _saleItems.clear();
                });
                _loadProducts();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecciona un almacén';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información del Cliente (Opcional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelection() {
    if (_availableProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No hay productos disponibles',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (_selectedWarehouseId == null)
                const Text(
                  'Selecciona un almacén primero',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar Productos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _availableProducts.length,
                itemBuilder: (context, index) {
                  final product = _availableProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'Stock: ${product.quantity} | Precio: \$${product.price.toStringAsFixed(2)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => _showAddProductDialog(product),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleItemsList() {
    if (_saleItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No hay productos en la venta',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Text(
                'Agrega productos desde la sección de arriba',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productos en la Venta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _saleItems.length,
              itemBuilder: (context, index) {
                final item = _saleItems[index];
                final product = _getProductById(item.productId);

                return ListTile(
                  title: Text(product?.name ?? 'Producto'),
                  subtitle: Text(
                    'Cantidad: ${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editSaleItem(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeSaleItem(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Método de Pago',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                DropdownMenuItem(
                  value: 'transfer',
                  child: Text('Transferencia'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final subtotal = _calculateSubtotal();
    final taxAmount = subtotal * _taxRate;
    final total = subtotal + taxAmount - _discountAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de la Venta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('\$${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            if (_taxRate > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Impuestos (${(_taxRate * 100).toStringAsFixed(1)}%):'),
                  Text('\$${taxAmount.toStringAsFixed(2)}'),
                ],
              ),
            ],
            if (_discountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descuento:'),
                  Text('-\$${_discountAmount.toStringAsFixed(2)}'),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog(Product product) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: product.price.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock disponible: ${product.quantity}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0;

              if (quantity > 0 && quantity <= product.quantity && price > 0) {
                _addSaleItem(product, quantity, price);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verifica la cantidad y el precio'),
                  ),
                );
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _addSaleItem(Product product, int quantity, double unitPrice) {
    final existingIndex = _saleItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      // Update existing item
      final existingItem = _saleItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;

      if (newQuantity <= product.quantity) {
        setState(() {
          _saleItems[existingIndex] = SaleItem(
            id: existingItem.id,
            saleId: existingItem.saleId,
            productId: product.id,
            quantity: newQuantity,
            unitPrice: unitPrice,
            totalPrice: newQuantity * unitPrice,
            createdAt: existingItem.createdAt,
          );
        });
      } else {
        _showError('No hay suficiente stock para esta cantidad');
      }
    } else {
      // Add new item
      setState(() {
        _saleItems.add(
          SaleItem(
            id: '', // Will be generated when saving
            saleId: '', // Will be set when saving
            productId: product.id,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: quantity * unitPrice,
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  void _editSaleItem(int index) {
    final item = _saleItems[index];
    final product = _getProductById(item.productId);

    if (product == null) return;

    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.unitPrice.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock disponible: ${product.quantity + item.quantity}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0;

              if (quantity > 0 &&
                  quantity <= (product.quantity + item.quantity) &&
                  price > 0) {
                setState(() {
                  _saleItems[index] = SaleItem(
                    id: item.id,
                    saleId: item.saleId,
                    productId: item.productId,
                    quantity: quantity,
                    unitPrice: price,
                    totalPrice: quantity * price,
                    createdAt: item.createdAt,
                  );
                });
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verifica la cantidad y el precio'),
                  ),
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _removeSaleItem(int index) {
    setState(() {
      _saleItems.removeAt(index);
    });
  }

  Product? _getProductById(String productId) {
    try {
      return _availableProducts.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  double _calculateSubtotal() {
    return _saleItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void _saveSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saleItems.isEmpty) {
      _showError('Agrega al menos un producto a la venta');
      return;
    }
    if (_selectedWarehouseId == null) {
      _showError('Selecciona un almacén');
      return;
    }

    final subtotal = _calculateSubtotal();
    final taxAmount = subtotal * _taxRate;
    final total = subtotal + taxAmount - _discountAmount;

    // Convert sale items to the format expected by the repository
    final items = _saleItems
        .map(
          (item) => {
            'productId': item.productId,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
            'totalPrice': item.totalPrice,
          },
        )
        .toList();

    final authState = context.read<AuthBloc>().state;
    String? currentUserId;

    if (authState is AuthAuthenticated) {
      currentUserId = authState.user.id;
    } else {
      _showError('Usuario no autenticado');
      return;
    }

    context.read<SalesBloc>().add(
      CreateSale(
        warehouseId: _selectedWarehouseId!,
        userId: currentUserId,
        customerName: _customerNameController.text.isNotEmpty
            ? _customerNameController.text
            : null,
        customerEmail: _customerEmailController.text.isNotEmpty
            ? _customerEmailController.text
            : null,
        customerPhone: _customerPhoneController.text.isNotEmpty
            ? _customerPhoneController.text
            : null,
        subtotal: subtotal,
        taxAmount: taxAmount,
        discountAmount: _discountAmount,
        totalAmount: total,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        items: items,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Simple SaleItem class for the form
class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
  });
}
