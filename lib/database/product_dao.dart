import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

/// Data Access Object for Product operations
class ProductDao {
  final AppDatabase _database;
  final _uuid = const Uuid();

  ProductDao(this._database);

  /// Get all products
  Future<List<Product>> getAllProducts() async {
    return await _database.select(_database.products).get();
  }

  /// Get products by warehouse
  Future<List<Product>> getProductsByWarehouse(String warehouseId) async {
    return await (_database.select(_database.products)
          ..where(
            (p) => p.warehouseId.equals(warehouseId) & p.isActive.equals(true),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  /// Get active products only
  Future<List<Product>> getActiveProducts() async {
    return await (_database.select(_database.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  /// Get product by ID
  Future<Product?> getProductById(String id) async {
    return await (_database.select(
      _database.products,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Get product by SKU
  Future<Product?> getProductBySku(String sku) async {
    return await (_database.select(
      _database.products,
    )..where((p) => p.sku.equals(sku))).getSingleOrNull();
  }

  /// Search products by name, SKU, or barcode
  Future<List<Product>> searchProducts(
    String query, {
    String? warehouseId,
  }) async {
    var select = _database.select(_database.products);

    if (warehouseId != null) {
      select = select
        ..where(
          (p) =>
              p.warehouseId.equals(warehouseId) &
              p.isActive.equals(true) &
              (p.name.contains(query) |
                  p.sku.contains(query) |
                  p.barcode.contains(query) |
                  p.description.contains(query)),
        );
    } else {
      select = select
        ..where(
          (p) =>
              p.isActive.equals(true) &
              (p.name.contains(query) |
                  p.sku.contains(query) |
                  p.barcode.contains(query) |
                  p.description.contains(query)),
        );
    }

    return await (select..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  /// Get low stock products
  Future<List<Product>> getLowStockProducts({String? warehouseId}) async {
    var select = _database.select(_database.products);

    if (warehouseId != null) {
      select = select
        ..where(
          (p) =>
              p.warehouseId.equals(warehouseId) &
              p.isActive.equals(true) &
              p.quantity.isSmallerOrEqual(p.minStock),
        );
    } else {
      select = select
        ..where(
          (p) =>
              p.isActive.equals(true) & p.quantity.isSmallerOrEqual(p.minStock),
        );
    }

    return await (select..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  /// Create new product
  Future<String> createProduct({
    required String warehouseId,
    required String name,
    required String sku,
    String? description,
    String? barcode,
    String? category,
    double price = 0.0,
    double cost = 0.0,
    int quantity = 0,
    int minStock = 0,
    int? maxStock,
    String unit = 'unit',
  }) async {
    final id = _uuid.v4();
    final product = ProductsCompanion(
      id: Value(id),
      warehouseId: Value(warehouseId),
      name: Value(name),
      description: Value(description),
      sku: Value(sku),
      barcode: Value(barcode),
      category: Value(category),
      price: Value(price),
      cost: Value(cost),
      quantity: Value(quantity),
      minStock: Value(minStock),
      maxStock: Value(maxStock),
      unit: Value(unit),
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _database.into(_database.products).insert(product);
    return id;
  }

  /// Update product
  Future<bool> updateProduct({
    required String id,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    String? category,
    double? price,
    double? cost,
    int? quantity,
    int? minStock,
    int? maxStock,
    String? unit,
    bool? isActive,
  }) async {
    final updateCompanion = ProductsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      sku: sku != null ? Value(sku) : const Value.absent(),
      barcode: barcode != null ? Value(barcode) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      price: price != null ? Value(price) : const Value.absent(),
      cost: cost != null ? Value(cost) : const Value.absent(),
      quantity: quantity != null ? Value(quantity) : const Value.absent(),
      minStock: minStock != null ? Value(minStock) : const Value.absent(),
      maxStock: maxStock != null ? Value(maxStock) : const Value.absent(),
      unit: unit != null ? Value(unit) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    final rowsAffected = await (_database.update(
      _database.products,
    )..where((p) => p.id.equals(id))).write(updateCompanion);

    return rowsAffected > 0;
  }

  /// Update product stock
  Future<bool> updateProductStock(String id, int newQuantity) async {
    return await updateProduct(id: id, quantity: newQuantity);
  }

  /// Soft delete product (mark as inactive)
  Future<bool> deactivateProduct(String id) async {
    return await updateProduct(id: id, isActive: false);
  }

  /// Hard delete product
  Future<bool> deleteProduct(String id) async {
    final rowsAffected = await (_database.delete(
      _database.products,
    )..where((p) => p.id.equals(id))).go();

    return rowsAffected > 0;
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(
    String category, {
    String? warehouseId,
  }) async {
    var select = _database.select(_database.products);

    if (warehouseId != null) {
      select = select
        ..where(
          (p) =>
              p.warehouseId.equals(warehouseId) &
              p.isActive.equals(true) &
              p.category.equals(category),
        );
    } else {
      select = select
        ..where((p) => p.isActive.equals(true) & p.category.equals(category));
    }

    return await (select..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  /// Get all categories
  Future<List<String>> getAllCategories({String? warehouseId}) async {
    var select = _database.selectOnly(_database.products)
      ..addColumns([_database.products.category])
      ..groupBy([_database.products.category])
      ..where(
        _database.products.category.isNotNull() &
            _database.products.isActive.equals(true),
      );

    if (warehouseId != null) {
      select = select
        ..where(_database.products.warehouseId.equals(warehouseId));
    }

    final results = await select.get();
    return results
        .map((row) => row.read(_database.products.category))
        .whereType<String>()
        .toList();
  }

  /// Check if SKU exists
  Future<bool> skuExists(String sku, {String? excludeId}) async {
    var query = _database.select(_database.products)
      ..where((p) => p.sku.equals(sku));

    if (excludeId != null) {
      query = query..where((p) => p.id.isNotValue(excludeId));
    }

    final product = await query.getSingleOrNull();
    return product != null;
  }

  /// Mark product as synced
  Future<void> markAsSynced(String id) async {
    await (_database.update(_database.products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(lastSyncAt: Value(DateTime.now())));
  }

  /// Get products that need sync
  Future<List<Product>> getProductsNeedingSync() async {
    return await (_database.select(_database.products)..where(
          (p) => p.lastSyncAt.isNull() | p.updatedAt.isBiggerThan(p.lastSyncAt),
        ))
        .get();
  }

  /// Get product statistics for warehouse
  Future<Map<String, dynamic>> getProductStats(String warehouseId) async {
    // Total products
    final totalProducts =
        await (_database.selectOnly(_database.products)
              ..addColumns([_database.products.id.count()])
              ..where(
                _database.products.warehouseId.equals(warehouseId) &
                    _database.products.isActive.equals(true),
              ))
            .map((row) => row.read(_database.products.id.count()) ?? 0)
            .getSingle();

    // Total stock value (calculated in Dart since Drift has type issues with cross-column operations)
    final products =
        await (_database.select(_database.products)..where(
              (p) =>
                  p.warehouseId.equals(warehouseId) & p.isActive.equals(true),
            ))
            .get();

    final totalStockValue = products.fold<double>(
      0.0,
      (sum, product) => sum + (product.quantity * product.cost),
    );

    // Low stock count - using simpler approach due to Drift limitations with column comparisons
    final lowStockProducts =
        await (_database.select(_database.products)..where(
              (p) =>
                  p.warehouseId.equals(warehouseId) & p.isActive.equals(true),
            ))
            .get();

    final lowStockCount = lowStockProducts
        .where((p) => p.quantity <= p.minStock)
        .length;

    // Out of stock count
    final outOfStockCount = lowStockProducts
        .where((p) => p.quantity == 0)
        .length;

    return {
      'totalProducts': totalProducts,
      'totalStockValue': totalStockValue,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
    };
  }
}
