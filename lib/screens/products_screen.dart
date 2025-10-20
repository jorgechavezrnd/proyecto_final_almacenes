import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/product_bloc.dart';
import '../database/database.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  final Warehouse warehouse;
  final String? userRole;

  const ProductsScreen({super.key, required this.warehouse, this.userRole});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  bool _showLowStockOnly = false;

  bool get isAdmin => widget.userRole?.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(
      LoadProducts(warehouseId: widget.warehouse.id),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Productos'),
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
          IconButton(
            icon: Icon(
              _showLowStockOnly ? Icons.warning : Icons.warning_outlined,
              color: _showLowStockOnly ? Colors.orange : null,
            ),
            onPressed: () {
              setState(() => _showLowStockOnly = !_showLowStockOnly);
              if (_showLowStockOnly) {
                context.read<ProductBloc>().add(
                  LoadLowStockProducts(warehouseId: widget.warehouse.id),
                );
              } else {
                context.read<ProductBloc>().add(
                  LoadProducts(warehouseId: widget.warehouse.id),
                );
              }
            },
            tooltip: _showLowStockOnly
                ? 'Mostrar todos los productos'
                : 'Mostrar productos con stock bajo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProductBloc>().add(
                RefreshProducts(warehouseId: widget.warehouse.id),
              );
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductBloc>().add(
                            LoadProducts(warehouseId: widget.warehouse.id),
                          );
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  context.read<ProductBloc>().add(
                    LoadProducts(warehouseId: widget.warehouse.id),
                  );
                } else {
                  context.read<ProductBloc>().add(
                    SearchProducts(
                      query: value,
                      warehouseId: widget.warehouse.id,
                    ),
                  );
                }
              },
            ),
          ),
          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state is ProductError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else if (state is ProductOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is ProductLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ProductError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar productos',
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
                            context.read<ProductBloc>().add(
                              LoadProducts(warehouseId: widget.warehouse.id),
                            );
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                List<Product> products = [];
                bool isSearchResult = false;
                String? searchQuery;
                bool isLowStockFilter = false;

                if (state is ProductLoaded) {
                  products = state.products;
                  isSearchResult = state.isSearchResult;
                  searchQuery = state.searchQuery;
                  isLowStockFilter = state.isLowStockFilter;
                } else if (state is ProductOperationSuccess) {
                  products = state.products;
                } else if (state is ProductSyncing) {
                  products = state.products;
                }

                if (products.isEmpty) {
                  String emptyMessage;
                  String emptySubtitle;
                  IconData emptyIcon;

                  if (isSearchResult) {
                    emptyMessage = 'Sin resultados';
                    emptySubtitle =
                        'No se encontraron productos para "$searchQuery"';
                    emptyIcon = Icons.search_off;
                  } else if (isLowStockFilter) {
                    emptyMessage = 'Sin productos con stock bajo';
                    emptySubtitle =
                        'Todos los productos tienen stock suficiente';
                    emptyIcon = Icons.check_circle_outline;
                  } else {
                    emptyMessage = 'No hay productos registrados';
                    emptySubtitle = 'Crea tu primer producto para este almacén';
                    emptyIcon = Icons.inventory_2_outlined;
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(emptyIcon, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptySubtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (!isSearchResult &&
                            !isLowStockFilter &&
                            isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToCreateProduct(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Crear Producto'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ProductBloc>().add(
                      RefreshProducts(warehouseId: widget.warehouse.id),
                    );
                  },
                  child: Column(
                    children: [
                      if (isSearchResult || isLowStockFilter)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: Colors.blue[50],
                          child: Row(
                            children: [
                              Icon(
                                isLowStockFilter ? Icons.warning : Icons.search,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isLowStockFilter
                                      ? '${products.length} productos con stock bajo'
                                      : '${products.length} resultados para "$searchQuery"',
                                  style: TextStyle(color: Colors.blue[700]),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _showLowStockOnly = false);
                                  context.read<ProductBloc>().add(
                                    LoadProducts(
                                      warehouseId: widget.warehouse.id,
                                    ),
                                  );
                                },
                                child: const Text('Limpiar'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _ProductCard(
                              product: product,
                              isAdmin: isAdmin,
                              onTap: isAdmin
                                  ? () =>
                                        _navigateToEditProduct(context, product)
                                  : () {},
                              onEdit: () =>
                                  _navigateToEditProduct(context, product),
                              onDelete: () =>
                                  _showDeleteConfirmation(context, product),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToCreateProduct(context),
              tooltip: 'Crear Producto',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _navigateToCreateProduct(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(warehouse: widget.warehouse),
      ),
    );
  }

  void _navigateToEditProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ProductFormScreen(warehouse: widget.warehouse, product: product),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Producto'),
          content: Text(
            '¿Estás seguro de que deseas eliminar el producto "${product.name}"?\n\n'
            'Esta acción desactivará el producto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<ProductBloc>().add(DeleteProduct(product.id));
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  bool get isLowStock => product.quantity <= product.minStock;

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
                      color: product.isActive
                          ? (isLowStock
                                ? Colors.orange[100]
                                : Colors.green[100])
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: product.isActive
                          ? (isLowStock
                                ? Colors.orange[700]
                                : Colors.green[700])
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
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: product.isActive
                                    ? null
                                    : Colors.grey[600],
                              ),
                        ),
                        Text(
                          'SKU: ${product.sku}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                        ),
                        if (product.category != null &&
                            product.category!.isNotEmpty)
                          Text(
                            product.category!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.blue[600]),
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
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  product.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  // Stock
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        Row(
                          children: [
                            Text(
                              '${product.quantity}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isLowStock
                                        ? Colors.orange[700]
                                        : null,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.unit,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (isLowStock) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.warning,
                                size: 16,
                                color: Colors.orange[700],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: product.isActive
                          ? Colors.green[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.isActive ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: product.isActive
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
              if (isLowStock) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stock bajo (mínimo: ${product.minStock})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
