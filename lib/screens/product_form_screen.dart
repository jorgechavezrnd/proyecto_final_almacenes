import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/product_bloc.dart';
import '../database/database.dart';

class ProductFormScreen extends StatefulWidget {
  final Warehouse warehouse;
  final Product? product;

  const ProductFormScreen({super.key, required this.warehouse, this.product});

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();
  final _unitController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _commonUnits = [
    'unit',
    'pcs',
    'kg',
    'g',
    'l',
    'ml',
    'm',
    'cm',
    'box',
    'pack',
  ];

  final List<String> _commonCategories = [
    'Electrónicos',
    'Ropa',
    'Alimentos',
    'Bebidas',
    'Hogar',
    'Oficina',
    'Herramientas',
    'Salud',
    'Belleza',
    'Deportes',
    'Juguetes',
    'Libros',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _populateFields();
    } else {
      _unitController.text = 'unit';
    }
  }

  void _populateFields() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _skuController.text = product.sku;
    _barcodeController.text = product.barcode ?? '';
    _categoryController.text = product.category ?? '';
    _priceController.text = product.price.toString();
    _costController.text = product.cost.toString();
    _quantityController.text = product.quantity.toString();
    _minStockController.text = product.minStock.toString();
    _maxStockController.text = product.maxStock?.toString() ?? '';
    _unitController.text = product.unit;
    _isActive = product.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isEditing ? 'Editar Producto' : 'Crear Producto'),
            Text(
              widget.warehouse.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: BlocListener<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductLoading) {
            setState(() => _isLoading = true);
          } else {
            setState(() => _isLoading = false);
          }

          if (state is ProductOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is ProductError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información Básica',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Producto *',
                            hintText: 'Ej: Laptop Dell Inspiron',
                            prefixIcon: Icon(Icons.inventory_2),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            if (value.trim().length < 2) {
                              return 'El nombre debe tener al menos 2 caracteres';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Descripción detallada del producto',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skuController,
                                decoration: const InputDecoration(
                                  labelText: 'SKU *',
                                  hintText: 'Ej: LAP-DELL-001',
                                  prefixIcon: Icon(Icons.qr_code),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'El SKU es obligatorio';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'El SKU debe tener al menos 3 caracteres';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _barcodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Código de Barras',
                                  hintText: 'Opcional',
                                  prefixIcon: Icon(Icons.barcode_reader),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !_isLoading,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _categoryController.text.isEmpty
                              ? null
                              : _categoryController.text,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Seleccionar categoría'),
                            ),
                            ..._commonCategories.map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  _categoryController.text = value ?? '';
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precios',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Precio de Venta *',
                                  hintText: '0.00',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'El precio es obligatorio';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Ingresa un precio válido';
                                  }
                                  if (double.parse(value) < 0) {
                                    return 'El precio no puede ser negativo';
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _costController,
                                decoration: const InputDecoration(
                                  labelText: 'Costo',
                                  hintText: '0.00',
                                  prefixIcon: Icon(Icons.money_off),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (double.tryParse(value) == null) {
                                      return 'Ingresa un costo válido';
                                    }
                                    if (double.parse(value) < 0) {
                                      return 'El costo no puede ser negativo';
                                    }
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventario',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Cantidad Actual',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.inventory),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (int.tryParse(value) == null) {
                                      return 'Ingresa una cantidad válida';
                                    }
                                    if (int.parse(value) < 0) {
                                      return 'La cantidad no puede ser negativa';
                                    }
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _unitController.text.isEmpty
                                    ? 'unit'
                                    : _unitController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Unidad',
                                  prefixIcon: Icon(Icons.straighten),
                                  border: OutlineInputBorder(),
                                ),
                                items: _commonUnits
                                    .map(
                                      (unit) => DropdownMenuItem(
                                        value: unit,
                                        child: Text(unit),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        _unitController.text = value ?? 'unit';
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minStockController,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Mínimo',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.warning_amber),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (int.tryParse(value) == null) {
                                      return 'Ingresa un stock válido';
                                    }
                                    if (int.parse(value) < 0) {
                                      return 'El stock no puede ser negativo';
                                    }
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _maxStockController,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Máximo',
                                  hintText: 'Opcional',
                                  prefixIcon: Icon(Icons.inventory_2),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (int.tryParse(value) == null) {
                                      return 'Ingresa un stock válido';
                                    }
                                    if (int.parse(value) < 0) {
                                      return 'El stock no puede ser negativo';
                                    }

                                    // Validate that max stock is greater than min stock
                                    final minStock =
                                        int.tryParse(
                                          _minStockController.text,
                                        ) ??
                                        0;
                                    if (int.parse(value) <= minStock) {
                                      return 'Debe ser mayor al stock mínimo';
                                    }
                                  }
                                  return null;
                                },
                                enabled: !_isLoading,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Producto Activo'),
                            subtitle: Text(
                              _isActive
                                  ? 'El producto está activo y disponible'
                                  : 'El producto está desactivado',
                            ),
                            value: _isActive,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() => _isActive = value);
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        child: Text(
                          widget.isEditing
                              ? 'Guardar Cambios'
                              : 'Crear Producto',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '* Campos obligatorios',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final sku = _skuController.text.trim();
    final barcode = _barcodeController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final minStock = int.tryParse(_minStockController.text) ?? 0;
    final maxStock = _maxStockController.text.isNotEmpty
        ? int.tryParse(_maxStockController.text)
        : null;
    final unit = _unitController.text.trim();

    if (widget.isEditing) {
      context.read<ProductBloc>().add(
        UpdateProduct(
          id: widget.product!.id,
          name: name,
          description: description.isEmpty ? null : description,
          sku: sku,
          barcode: barcode.isEmpty ? null : barcode,
          category: category.isEmpty ? null : category,
          price: price,
          cost: cost,
          quantity: quantity,
          minStock: minStock,
          maxStock: maxStock,
          unit: unit,
          isActive: _isActive,
        ),
      );
    } else {
      context.read<ProductBloc>().add(
        CreateProduct(
          warehouseId: widget.warehouse.id,
          name: name,
          sku: sku,
          description: description.isEmpty ? null : description,
          barcode: barcode.isEmpty ? null : barcode,
          category: category.isEmpty ? null : category,
          price: price,
          cost: cost,
          quantity: quantity,
          minStock: minStock,
          maxStock: maxStock,
          unit: unit,
        ),
      );
    }
  }
}
