import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../database/database.dart';
import '../repositories/inventory_repository.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductEvent {
  final String? warehouseId;

  const LoadProducts({this.warehouseId});

  @override
  List<Object?> get props => [warehouseId];
}

class RefreshProducts extends ProductEvent {
  final String? warehouseId;

  const RefreshProducts({this.warehouseId});

  @override
  List<Object?> get props => [warehouseId];
}

class SearchProducts extends ProductEvent {
  final String query;
  final String? warehouseId;

  const SearchProducts({required this.query, this.warehouseId});

  @override
  List<Object?> get props => [query, warehouseId];
}

class LoadLowStockProducts extends ProductEvent {
  final String? warehouseId;

  const LoadLowStockProducts({this.warehouseId});

  @override
  List<Object?> get props => [warehouseId];
}

class CreateProduct extends ProductEvent {
  final String warehouseId;
  final String name;
  final String sku;
  final String? description;
  final String? barcode;
  final String? category;
  final double price;
  final double cost;
  final int quantity;
  final int minStock;
  final int? maxStock;
  final String unit;

  const CreateProduct({
    required this.warehouseId,
    required this.name,
    required this.sku,
    this.description,
    this.barcode,
    this.category,
    this.price = 0.0,
    this.cost = 0.0,
    this.quantity = 0,
    this.minStock = 0,
    this.maxStock,
    this.unit = 'unit',
  });

  @override
  List<Object?> get props => [
    warehouseId,
    name,
    sku,
    description,
    barcode,
    category,
    price,
    cost,
    quantity,
    minStock,
    maxStock,
    unit,
  ];
}

class UpdateProduct extends ProductEvent {
  final String id;
  final String? name;
  final String? description;
  final String? sku;
  final String? barcode;
  final String? category;
  final double? price;
  final double? cost;
  final int? quantity;
  final int? minStock;
  final int? maxStock;
  final String? unit;
  final bool? isActive;

  const UpdateProduct({
    required this.id,
    this.name,
    this.description,
    this.sku,
    this.barcode,
    this.category,
    this.price,
    this.cost,
    this.quantity,
    this.minStock,
    this.maxStock,
    this.unit,
    this.isActive,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    sku,
    barcode,
    category,
    price,
    cost,
    quantity,
    minStock,
    maxStock,
    unit,
    isActive,
  ];
}

class DeleteProduct extends ProductEvent {
  final String id;

  const DeleteProduct(this.id);

  @override
  List<Object> get props => [id];
}

class SyncProducts extends ProductEvent {
  const SyncProducts();
}

// ============================================================================
// STATES
// ============================================================================

abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductLoaded extends ProductState {
  final List<Product> products;
  final bool isSearchResult;
  final String? searchQuery;
  final bool isLowStockFilter;
  final String? currentWarehouseId;

  const ProductLoaded({
    required this.products,
    this.isSearchResult = false,
    this.searchQuery,
    this.isLowStockFilter = false,
    this.currentWarehouseId,
  });

  @override
  List<Object?> get props => [
    products,
    isSearchResult,
    searchQuery,
    isLowStockFilter,
    currentWarehouseId,
  ];

  ProductLoaded copyWith({
    List<Product>? products,
    bool? isSearchResult,
    String? searchQuery,
    bool? isLowStockFilter,
    String? currentWarehouseId,
  }) {
    return ProductLoaded(
      products: products ?? this.products,
      isSearchResult: isSearchResult ?? this.isSearchResult,
      searchQuery: searchQuery ?? this.searchQuery,
      isLowStockFilter: isLowStockFilter ?? this.isLowStockFilter,
      currentWarehouseId: currentWarehouseId ?? this.currentWarehouseId,
    );
  }
}

class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object> get props => [message];
}

class ProductOperationSuccess extends ProductState {
  final String message;
  final List<Product> products;

  const ProductOperationSuccess({
    required this.message,
    required this.products,
  });

  @override
  List<Object> get props => [message, products];
}

class ProductSyncing extends ProductState {
  final List<Product> products;

  const ProductSyncing(this.products);

  @override
  List<Object> get props => [products];
}

// ============================================================================
// BLOC
// ============================================================================

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final InventoryRepository _repository;

  ProductBloc({required InventoryRepository repository})
    : _repository = repository,
      super(const ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<RefreshProducts>(_onRefreshProducts);
    on<SearchProducts>(_onSearchProducts);
    on<LoadLowStockProducts>(_onLoadLowStockProducts);
    on<CreateProduct>(_onCreateProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<SyncProducts>(_onSyncProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductLoading());

      List<Product> products;
      if (event.warehouseId != null) {
        products = await _repository.getProductsByWarehouse(event.warehouseId!);
      } else {
        // If no warehouse specified, we'd need a method to get all products
        // For now, return empty list
        products = [];
      }

      emit(
        ProductLoaded(
          products: products,
          currentWarehouseId: event.warehouseId,
        ),
      );
    } catch (e) {
      emit(ProductError('Error loading products: $e'));
    }
  }

  Future<void> _onRefreshProducts(
    RefreshProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      List<Product> products;
      if (event.warehouseId != null) {
        products = await _repository.getProductsByWarehouse(event.warehouseId!);
      } else {
        products = [];
      }

      emit(
        ProductLoaded(
          products: products,
          currentWarehouseId: event.warehouseId,
        ),
      );
    } catch (e) {
      if (state is ProductLoaded) {
        // Keep current state on refresh error
        return;
      }
      emit(ProductError('Error refreshing products: $e'));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      if (event.query.isEmpty) {
        add(LoadProducts(warehouseId: event.warehouseId));
        return;
      }

      final products = await _repository.searchProducts(
        event.query,
        warehouseId: event.warehouseId,
      );

      emit(
        ProductLoaded(
          products: products,
          isSearchResult: true,
          searchQuery: event.query,
          currentWarehouseId: event.warehouseId,
        ),
      );
    } catch (e) {
      emit(ProductError('Error searching products: $e'));
    }
  }

  Future<void> _onLoadLowStockProducts(
    LoadLowStockProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final products = await _repository.getLowStockProducts(
        warehouseId: event.warehouseId,
      );

      emit(
        ProductLoaded(
          products: products,
          isLowStockFilter: true,
          currentWarehouseId: event.warehouseId,
        ),
      );
    } catch (e) {
      emit(ProductError('Error loading low stock products: $e'));
    }
  }

  Future<void> _onCreateProduct(
    CreateProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final result = await _repository.createProduct(
        warehouseId: event.warehouseId,
        name: event.name,
        sku: event.sku,
        description: event.description,
        barcode: event.barcode,
        category: event.category,
        price: event.price,
        cost: event.cost,
        quantity: event.quantity,
        minStock: event.minStock,
        maxStock: event.maxStock,
        unit: event.unit,
      );

      if (result.isSuccess) {
        final products = await _repository.getProductsByWarehouse(
          event.warehouseId,
        );
        emit(
          ProductOperationSuccess(
            message: 'Product created successfully',
            products: products,
          ),
        );
      } else {
        emit(ProductError(result.error ?? 'Failed to create product'));
      }
    } catch (e) {
      emit(ProductError('Error creating product: $e'));
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final result = await _repository.updateProduct(
        id: event.id,
        name: event.name,
        description: event.description,
        sku: event.sku,
        barcode: event.barcode,
        category: event.category,
        price: event.price,
        cost: event.cost,
        quantity: event.quantity,
        minStock: event.minStock,
        maxStock: event.maxStock,
        unit: event.unit,
        isActive: event.isActive,
      );

      if (result.isSuccess) {
        // Reload products based on current state
        String? warehouseId;
        if (state is ProductLoaded) {
          warehouseId = (state as ProductLoaded).currentWarehouseId;
        }

        final products = warehouseId != null
            ? await _repository.getProductsByWarehouse(warehouseId)
            : <Product>[];

        emit(
          ProductOperationSuccess(
            message: 'Product updated successfully',
            products: products,
          ),
        );
      } else {
        emit(ProductError(result.error ?? 'Failed to update product'));
      }
    } catch (e) {
      emit(ProductError('Error updating product: $e'));
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final result = await _repository.deleteProduct(event.id);

      if (result.isSuccess) {
        // Reload products based on current state
        String? warehouseId;
        if (state is ProductLoaded) {
          warehouseId = (state as ProductLoaded).currentWarehouseId;
        }

        final products = warehouseId != null
            ? await _repository.getProductsByWarehouse(warehouseId)
            : <Product>[];

        emit(
          ProductOperationSuccess(
            message: 'Product deleted successfully',
            products: products,
          ),
        );
      } else {
        emit(ProductError(result.error ?? 'Failed to delete product'));
      }
    } catch (e) {
      emit(ProductError('Error deleting product: $e'));
    }
  }

  Future<void> _onSyncProducts(
    SyncProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      if (state is ProductLoaded) {
        final currentState = state as ProductLoaded;
        emit(ProductSyncing(currentState.products));
      }

      await _repository.syncToServer();

      // Reload based on current state
      String? warehouseId;
      if (state is ProductSyncing) {
        final currentState = state as ProductSyncing;
        // Try to get warehouse ID from current products
        if (currentState.products.isNotEmpty) {
          warehouseId = currentState.products.first.warehouseId;
        }
      }

      final products = warehouseId != null
          ? await _repository.getProductsByWarehouse(warehouseId)
          : <Product>[];

      emit(ProductLoaded(products: products, currentWarehouseId: warehouseId));
    } catch (e) {
      if (state is ProductSyncing) {
        final currentState = state as ProductSyncing;
        emit(
          ProductLoaded(
            products: currentState.products,
            currentWarehouseId: currentState.products.isNotEmpty
                ? currentState.products.first.warehouseId
                : null,
          ),
        );
      }
      emit(ProductError('Sync failed: $e'));
    }
  }
}
