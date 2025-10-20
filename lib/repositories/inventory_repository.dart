import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/warehouse_dao.dart';
import '../database/product_dao.dart';
import '../database/sales_dao.dart';
import '../services/supabase_service.dart';
import 'auth_repository.dart';

/// Repository for managing inventory operations with offline-first architecture
class InventoryRepository {
  static InventoryRepository? _instance;
  static InventoryRepository get instance =>
      _instance ??= InventoryRepository._();

  InventoryRepository._();

  late final AppDatabase _database;
  late final WarehouseDao _warehouseDao;
  late final ProductDao _productDao;
  late final SalesDao _salesDao;
  final SupabaseService _supabaseService = SupabaseService.instance;

  /// Initialize the repository
  Future<void> initialize(AppDatabase database) async {
    _database = database;

    // Ensure database is initialized by testing each table
    await _ensureDatabaseInitialized();

    _warehouseDao = WarehouseDao(_database);
    _productDao = ProductDao(_database);
    _salesDao = SalesDao(_database);
  }

  /// Ensure all required tables exist
  Future<void> _ensureDatabaseInitialized() async {
    try {
      // Test each table by running a simple query
      await (_database.select(_database.userSessions)..limit(1)).get();
      await (_database.select(_database.warehouses)..limit(1)).get();
      await (_database.select(_database.products)..limit(1)).get();
      await (_database.select(_database.inventoryMovements)..limit(1)).get();
      await (_database.select(_database.sales)..limit(1)).get();
      await (_database.select(_database.saleItems)..limit(1)).get();
    } catch (e) {
      // The error indicates tables don't exist, but Drift should handle this
      // through the migration strategy. If this error persists, the database
      // file might be corrupted and need to be deleted.
      rethrow;
    }
  }

  // ============================================================================
  // WAREHOUSE OPERATIONS
  // ============================================================================

  /// Get all warehouses (offline-first)
  Future<List<Warehouse>> getAllWarehouses() async {
    try {
      // Try to sync from server first if online
      await _syncWarehousesFromServer();
    } catch (e) {
      // Continue with local data if sync fails
    }
    return await _warehouseDao.getAllWarehouses();
  }

  /// Get active warehouses only
  Future<List<Warehouse>> getActiveWarehouses() async {
    try {
      await _syncWarehousesFromServer();
    } catch (e) {
      // Continue with local data if sync fails
    }
    return await _warehouseDao.getActiveWarehouses();
  }

  /// Create new warehouse
  Future<InventoryResult<String>> createWarehouse({
    required String name,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? email,
  }) async {
    try {
      final localId = await _warehouseDao.createWarehouse(
        name: name,
        description: description,
        address: address,
        city: city,
        phone: phone,
        email: email,
      );

      // Try to sync to Supabase
      try {
        final warehouse = await _warehouseDao.getWarehouseById(localId);
        if (warehouse != null) {
          await _syncWarehouseToServer(warehouse);
        }
      } catch (e) {
        // Warehouse saved locally, will sync later
      }

      return InventoryResult.success(localId);
    } catch (e) {
      return InventoryResult.error('Error creating warehouse: $e');
    }
  }

  /// Update warehouse
  Future<InventoryResult<bool>> updateWarehouse({
    required String id,
    String? name,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? email,
    bool? isActive,
  }) async {
    try {
      final success = await _warehouseDao.updateWarehouse(
        id: id,
        name: name,
        description: description,
        address: address,
        city: city,
        phone: phone,
        email: email,
        isActive: isActive,
      );

      if (success) {
        // Try to sync to server
        try {
          final warehouse = await _warehouseDao.getWarehouseById(id);
          if (warehouse != null) {
            await _syncWarehouseToServer(warehouse);
          }
        } catch (e) {
          // Will sync later
        }
      }

      return InventoryResult.success(success);
    } catch (e) {
      return InventoryResult.error('Error updating warehouse: $e');
    }
  }

  /// Delete warehouse
  Future<InventoryResult<bool>> deleteWarehouse(String id) async {
    try {
      final success = await _warehouseDao.deactivateWarehouse(id);

      if (success) {
        // Try to sync deletion to server
        try {
          await _supabaseService.client
              .from('warehouses')
              .update({'is_active': false})
              .eq('id', id);
        } catch (e) {
          // Will sync later
        }
      }

      return InventoryResult.success(success);
    } catch (e) {
      return InventoryResult.error('Error deleting warehouse: $e');
    }
  }

  // ============================================================================
  // PRODUCT OPERATIONS
  // ============================================================================

  /// Get products by warehouse
  Future<List<Product>> getProductsByWarehouse(String warehouseId) async {
    try {
      await _syncProductsFromServer(warehouseId);
    } catch (e) {
      // Continue with local data
    }
    return await _productDao.getProductsByWarehouse(warehouseId);
  }

  /// Create new product
  Future<InventoryResult<String>> createProduct({
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
    try {
      final existingSku = await _productDao.skuExists(sku);
      if (existingSku) {
        return InventoryResult.error('SKU already exists');
      }

      final localId = await _productDao.createProduct(
        warehouseId: warehouseId,
        name: name,
        sku: sku,
        description: description,
        barcode: barcode,
        category: category,
        price: price,
        cost: cost,
        quantity: quantity,
        minStock: minStock,
        maxStock: maxStock,
        unit: unit,
      );

      // Try to sync to server
      try {
        final product = await _productDao.getProductById(localId);
        if (product != null) {
          await _syncProductToServer(product);
        }
      } catch (e) {
        // Will sync later
      }

      return InventoryResult.success(localId);
    } catch (e) {
      return InventoryResult.error('Error creating product: $e');
    }
  }

  /// Update product
  Future<InventoryResult<bool>> updateProduct({
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
    try {
      // Check SKU uniqueness if updating SKU
      if (sku != null) {
        final existingSku = await _productDao.skuExists(sku, excludeId: id);
        if (existingSku) {
          return InventoryResult.error('SKU already exists');
        }
      }

      final success = await _productDao.updateProduct(
        id: id,
        name: name,
        description: description,
        sku: sku,
        barcode: barcode,
        category: category,
        price: price,
        cost: cost,
        quantity: quantity,
        minStock: minStock,
        maxStock: maxStock,
        unit: unit,
        isActive: isActive,
      );

      if (success) {
        // Try to sync to server
        try {
          final product = await _productDao.getProductById(id);
          if (product != null) {
            await _syncProductToServer(product);
          }
        } catch (e) {
          // Will sync later
        }
      }

      return InventoryResult.success(success);
    } catch (e) {
      return InventoryResult.error('Error updating product: $e');
    }
  }

  /// Delete product
  Future<InventoryResult<bool>> deleteProduct(String id) async {
    try {
      final success = await _productDao.deactivateProduct(id);

      if (success) {
        try {
          await _supabaseService.client
              .from('products')
              .update({'is_active': false})
              .eq('id', id);
        } catch (e) {
          // Will sync later
        }
      }

      return InventoryResult.success(success);
    } catch (e) {
      return InventoryResult.error('Error deleting product: $e');
    }
  }

  /// Search products
  Future<List<Product>> searchProducts(
    String query, {
    String? warehouseId,
  }) async {
    return await _productDao.searchProducts(query, warehouseId: warehouseId);
  }

  /// Get low stock products
  Future<List<Product>> getLowStockProducts({String? warehouseId}) async {
    return await _productDao.getLowStockProducts(warehouseId: warehouseId);
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Sync all pending changes to server
  Future<void> syncToServer() async {
    try {
      await _syncWarehousesToServer();
      await _syncProductsToServer();
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  /// Sync warehouses from server
  Future<void> _syncWarehousesFromServer() async {
    final response = await _supabaseService.client
        .from('warehouses')
        .select('*')
        .order('updated_at', ascending: false);

    for (final data in response) {
      await _upsertLocalWarehouse(data);
    }
  }

  /// Sync warehouse to server
  Future<void> _syncWarehouseToServer(Warehouse warehouse) async {
    final data = {
      'id': warehouse.id,
      'name': warehouse.name,
      'description': warehouse.description,
      'address': warehouse.address,
      'city': warehouse.city,
      'phone': warehouse.phone,
      'email': warehouse.email,
      'is_active': warehouse.isActive,
      'created_at': warehouse.createdAt.toIso8601String(),
      'updated_at': warehouse.updatedAt.toIso8601String(),
    };

    await _supabaseService.client.from('warehouses').upsert(data);

    await _warehouseDao.markAsSynced(warehouse.id);
  }

  /// Sync all warehouses to server
  Future<void> _syncWarehousesToServer() async {
    final warehouses = await _warehouseDao.getWarehousesNeedingSync();
    for (final warehouse in warehouses) {
      await _syncWarehouseToServer(warehouse);
    }
  }

  /// Sync products from server
  Future<void> _syncProductsFromServer(String? warehouseId) async {
    List<Map<String, dynamic>> response;

    if (warehouseId != null) {
      response = await _supabaseService.client
          .from('products')
          .select('*')
          .eq('warehouse_id', warehouseId)
          .order('updated_at', ascending: false);
    } else {
      response = await _supabaseService.client
          .from('products')
          .select('*')
          .order('updated_at', ascending: false);
    }

    for (final data in response) {
      await _upsertLocalProduct(data);
    }
  }

  /// Sync product to server
  Future<void> _syncProductToServer(Product product) async {
    try {
      final data = {
        'id': product.id,
        'warehouse_id': product.warehouseId,
        'name': product.name,
        'description': product.description,
        'sku': product.sku,
        'barcode': product.barcode,
        'category': product.category,
        'price': product.price,
        'cost': product.cost,
        'quantity': product.quantity,
        'min_stock': product.minStock,
        'max_stock': product.maxStock,
        'unit': product.unit,
        'is_active': product.isActive,
        'created_at': product.createdAt.toIso8601String(),
        'updated_at': product.updatedAt.toIso8601String(),
      };

      // Try to update first, if it fails, try to insert
      try {
        await _supabaseService.client
            .from('products')
            .update(data)
            .eq('id', product.id);
      } catch (updateError) {
        await _supabaseService.client.from('products').insert(data);
      }

      await _productDao.markAsSynced(product.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Sync all products to server
  Future<void> _syncProductsToServer() async {
    final products = await _productDao.getProductsNeedingSync();
    for (final product in products) {
      await _syncProductToServer(product);
    }
  }

  /// Upsert warehouse from server data
  Future<void> _upsertLocalWarehouse(Map<String, dynamic> data) async {
    final existing = await _warehouseDao.getWarehouseById(data['id']);

    if (existing == null) {
      // Create new
      await _database
          .into(_database.warehouses)
          .insert(
            WarehousesCompanion.insert(
              id: data['id'],
              name: data['name'],
              description: Value(data['description']),
              address: Value(data['address']),
              city: Value(data['city']),
              phone: Value(data['phone']),
              email: Value(data['email']),
              isActive: Value(data['is_active'] ?? true),
              createdAt: Value(DateTime.parse(data['created_at'])),
              updatedAt: Value(DateTime.parse(data['updated_at'])),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
    } else {
      // Update existing if server version is newer
      final serverUpdated = DateTime.parse(data['updated_at']);
      if (serverUpdated.isAfter(existing.updatedAt)) {
        await _warehouseDao.updateWarehouse(
          id: data['id'],
          name: data['name'],
          description: data['description'],
          address: data['address'],
          city: data['city'],
          phone: data['phone'],
          email: data['email'],
          isActive: data['is_active'] ?? true,
        );
        await _warehouseDao.markAsSynced(data['id']);
      }
    }
  }

  /// Upsert product from server data
  Future<void> _upsertLocalProduct(Map<String, dynamic> data) async {
    final existing = await _productDao.getProductById(data['id']);

    if (existing == null) {
      // Create new
      await _database
          .into(_database.products)
          .insert(
            ProductsCompanion.insert(
              id: data['id'],
              warehouseId: data['warehouse_id'],
              name: data['name'],
              description: Value(data['description']),
              sku: data['sku'],
              barcode: Value(data['barcode']),
              category: Value(data['category']),
              price: Value(data['price']?.toDouble() ?? 0.0),
              cost: Value(data['cost']?.toDouble() ?? 0.0),
              quantity: Value(data['quantity'] ?? 0),
              minStock: Value(data['min_stock'] ?? 0),
              maxStock: Value(data['max_stock']),
              unit: Value(data['unit'] ?? 'unit'),
              isActive: Value(data['is_active'] ?? true),
              createdAt: Value(DateTime.parse(data['created_at'])),
              updatedAt: Value(DateTime.parse(data['updated_at'])),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
    } else {
      // Update existing if server version is newer
      final serverUpdated = DateTime.parse(data['updated_at']);
      if (serverUpdated.isAfter(existing.updatedAt)) {
        await _productDao.updateProduct(
          id: data['id'],
          name: data['name'],
          description: data['description'],
          sku: data['sku'],
          barcode: data['barcode'],
          category: data['category'],
          price: data['price']?.toDouble() ?? 0.0,
          cost: data['cost']?.toDouble() ?? 0.0,
          quantity: data['quantity'] ?? 0,
          minStock: data['min_stock'] ?? 0,
          maxStock: data['max_stock'],
          unit: data['unit'] ?? 'unit',
          isActive: data['is_active'] ?? true,
        );
        await _productDao.markAsSynced(data['id']);
      }
    }
  }

  /// Check if we have pending sync operations
  Future<bool> hasPendingSync() async {
    final warehouses = await _warehouseDao.getWarehousesNeedingSync();
    final products = await _productDao.getProductsNeedingSync();
    return warehouses.isNotEmpty || products.isNotEmpty;
  }

  // ============================================================================
  // SALES METHODS
  // ============================================================================

  /// Get all sales
  Future<List<Sale>> getAllSales() async {
    return await _salesDao.getAllSales();
  }

  /// Get sales by date range
  Future<List<Sale>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _salesDao.getSalesByDateRange(startDate, endDate);
  }

  /// Get sales by warehouse
  Future<List<Sale>> getSalesByWarehouse(String warehouseId) async {
    return await _salesDao.getSalesByWarehouse(warehouseId);
  }

  /// Get sales by user
  Future<List<Sale>> getSalesByUser(String userId) async {
    return await _salesDao.getSalesByUser(userId);
  }

  /// Get sales by user and date range
  Future<List<Sale>> getSalesByUserAndDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final filteredSales = await _salesDao.getSalesByUserAndDateRange(
      userId,
      startDate,
      endDate,
    );

    return filteredSales;
  }

  /// Get sale with items
  Future<Map<String, dynamic>> getSaleWithItems(String saleId) async {
    return await _salesDao.getSaleWithItems(saleId);
  }

  /// Get sales summary
  Future<Map<String, dynamic>> getSalesSummary({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _salesDao.getSalesSummary(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Create new sale
  Future<InventoryResult<String>> createSale({
    required String warehouseId,
    required String userId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    required double subtotal,
    double taxAmount = 0.0,
    double discountAmount = 0.0,
    required double totalAmount,
    required String paymentMethod,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Create locally first (offline-first)
      final saleId = await _salesDao.createSale(
        warehouseId: warehouseId,
        userId: userId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        subtotal: subtotal,
        taxAmount: taxAmount,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        notes: notes,
        items: items,
      );

      // Try to sync to Supabase
      try {
        final sale = await _salesDao.getSaleById(saleId);
        if (sale != null) {
          await _syncSaleToSupabase(sale);

          // Sync sale items
          final saleItems = await _salesDao.getSaleItems(saleId);
          for (final item in saleItems) {
            await _syncSaleItemToSupabase(item);
          }

          // Sync affected products with updated quantities
          final affectedProductIds = items
              .map((item) => item['productId'] as String)
              .toSet();
          for (final productId in affectedProductIds) {
            final product = await _productDao.getProductById(productId);
            if (product != null) {
              await _syncProductToServer(product);
            }
          }
        }
      } catch (syncError) {
        // Continue even if sync fails (offline-first)
      }

      return InventoryResult.success(saleId);
    } catch (e) {
      return InventoryResult.error('Failed to create sale: $e');
    }
  }

  /// Delete sale
  Future<InventoryResult<bool>> deleteSale(String saleId) async {
    try {
      final success = await _salesDao.deleteSale(saleId);

      if (success) {
        // Try to sync deletion to Supabase
        try {
          await _supabaseService.client.from('sales').delete().eq('id', saleId);
        } catch (syncError) {
          // Continue even if sync fails
        }

        return InventoryResult.success(true);
      } else {
        return InventoryResult.error('Failed to delete sale');
      }
    } catch (e) {
      return InventoryResult.error('Failed to delete sale: $e');
    }
  }

  /// Sync sales to/from Supabase
  Future<void> syncSales() async {
    try {
      // Sync local sales to server
      final unsyncedSales = await _salesDao.getUnsyncedSales();
      for (final sale in unsyncedSales) {
        await _syncSaleToSupabase(sale);

        // Sync sale items
        final saleItems = await _salesDao.getSaleItems(sale.id);
        for (final item in saleItems) {
          await _syncSaleItemToSupabase(item);
        }

        await _salesDao.markAsSynced(sale.id);
      }

      // Sync server sales to local
      await _syncSalesFromSupabase();
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  /// Sync sale to Supabase
  Future<void> _syncSaleToSupabase(Sale sale) async {
    final data = {
      'id': sale.id,
      'warehouse_id': sale.warehouseId,
      'user_id': sale.userId,
      'customer_name': sale.customerName,
      'customer_email': sale.customerEmail,
      'customer_phone': sale.customerPhone,
      'subtotal': sale.subtotal,
      'tax_amount': sale.taxAmount,
      'discount_amount': sale.discountAmount,
      'total_amount': sale.totalAmount,
      'payment_method': sale.paymentMethod,
      'status': sale.status,
      'notes': sale.notes,
      'sale_date': sale.saleDate.toIso8601String(),
      'created_at': sale.createdAt.toIso8601String(),
      'updated_at': sale.updatedAt.toIso8601String(),
    };

    await _supabaseService.client.from('sales').upsert(data);
  }

  /// Sync sale item to Supabase
  Future<void> _syncSaleItemToSupabase(SaleItem item) async {
    final data = {
      'id': item.id,
      'sale_id': item.saleId,
      'product_id': item.productId,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
      'created_at': item.createdAt.toIso8601String(),
    };

    await _supabaseService.client.from('sale_items').upsert(data);
  }

  /// Sync sales from Supabase to local
  Future<void> _syncSalesFromSupabase() async {
    final response = await _supabaseService.client
        .from('sales')
        .select('*')
        .order('updated_at');

    for (final data in response) {
      await _upsertSaleFromServer(data);
    }

    // Sync sale items
    final itemsResponse = await _supabaseService.client
        .from('sale_items')
        .select('*')
        .order('created_at');

    for (final data in itemsResponse) {
      await _upsertSaleItemFromServer(data);
    }
  }

  /// Upsert sale from server data
  Future<void> _upsertSaleFromServer(Map<String, dynamic> data) async {
    // Use SalesDao method instead of direct database access
    await _salesDao.upsertSaleFromServer(data);
  }

  /// Upsert sale item from server data
  Future<void> _upsertSaleItemFromServer(Map<String, dynamic> data) async {
    // Use SalesDao method instead of direct database access
    await _salesDao.upsertSaleItemFromServer(data);
  }

  /// Get all sales grouped by user (for admin reports)
  Future<Map<String, List<Sale>>> getAllSalesByUser() async {
    final allSales = await _salesDao.getAllSales();

    final Map<String, List<Sale>> salesByUserId = {};
    for (final sale in allSales) {
      if (sale.userId.isNotEmpty) {
        salesByUserId.putIfAbsent(sale.userId, () => []).add(sale);
      }
    }

    // Convert user IDs to user names using AuthRepository
    final Map<String, List<Sale>> salesByUserName = {};
    final authRepo = AuthRepository.instance;

    for (final entry in salesByUserId.entries) {
      final userId = entry.key;
      final sales = entry.value;

      // Try to get user name from Supabase
      String userName = userId; // fallback to user ID
      try {
        // Get all users to find the user name for this ID
        final users = await authRepo.getAllUsers();
        final user = users.firstWhere(
          (user) => user.id == userId,
          orElse: () => throw Exception('User not found'),
        );
        userName = user.userName.isNotEmpty ? user.userName : user.email;
      } catch (e) {
        // Keep userId as fallback
      }

      salesByUserName[userName] = sales;
    }

    return salesByUserName;
  }

  /// Get all sales grouped by user and filtered by date range (for admin reports)
  Future<Map<String, List<Sale>>> getAllSalesByUserAndDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final adjustedStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    );
    final adjustedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final allSales = await _salesDao.getSalesByDateRange(
      adjustedStartDate,
      adjustedEndDate,
    );

    final Map<String, List<Sale>> salesByUserId = {};
    for (final sale in allSales) {
      if (sale.userId.isNotEmpty) {
        salesByUserId.putIfAbsent(sale.userId, () => []).add(sale);
      }
    }

    // Convert user IDs to user names using AuthRepository
    final Map<String, List<Sale>> salesByUserName = {};
    final authRepo = AuthRepository.instance;

    for (final entry in salesByUserId.entries) {
      final userId = entry.key;
      final sales = entry.value;

      // Try to get user name from Supabase
      String userName = userId; // fallback to user ID
      try {
        // Get all users to find the user name for this ID
        final users = await authRepo.getAllUsers();
        final user = users.firstWhere(
          (user) => user.id == userId,
          orElse: () => throw Exception('User not found'),
        );
        userName = user.userName.isNotEmpty ? user.userName : user.email;
      } catch (e) {
        // Keep userId as fallback
      }

      salesByUserName[userName] = sales;
    }

    return salesByUserName;
  }
}

/// Result wrapper for inventory operations
class InventoryResult<T> {
  final bool isSuccess;
  final String? error;
  final T? data;

  InventoryResult._({required this.isSuccess, this.error, this.data});

  factory InventoryResult.success(T data) {
    return InventoryResult._(isSuccess: true, data: data);
  }

  factory InventoryResult.error(String error) {
    return InventoryResult._(isSuccess: false, error: error);
  }
}
