import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

class SalesDao {
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  SalesDao(this._database);

  /// Get all sales
  Future<List<Sale>> getAllSales() async {
    return await _database.select(_database.sales).get();
  }

  /// Get sales by date range
  Future<List<Sale>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result =
        await (_database.select(_database.sales)
              ..where(
                (s) =>
                    s.saleDate.isBiggerOrEqualValue(startDate) &
                    s.saleDate.isSmallerOrEqualValue(endDate),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
            .get();

    return result;
  }

  /// Get sales by warehouse
  Future<List<Sale>> getSalesByWarehouse(String warehouseId) async {
    return await (_database.select(_database.sales)
          ..where((s) => s.warehouseId.equals(warehouseId))
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  /// Get sales by user
  Future<List<Sale>> getSalesByUser(String userId) async {
    return await (_database.select(_database.sales)
          ..where((s) => s.userId.equals(userId))
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
        .get();
  }

  /// Get sales by user and date range
  Future<List<Sale>> getSalesByUserAndDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result =
        await (_database.select(_database.sales)
              ..where(
                (s) =>
                    s.userId.equals(userId) &
                    s.saleDate.isBiggerOrEqualValue(startDate) &
                    s.saleDate.isSmallerOrEqualValue(endDate),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
            .get();

    return result;
  }

  /// Get sale by ID
  Future<Sale?> getSaleById(String id) async {
    return await (_database.select(
      _database.sales,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Get sale items for a specific sale
  Future<List<SaleItem>> getSaleItems(String saleId) async {
    return await (_database.select(
      _database.saleItems,
    )..where((si) => si.saleId.equals(saleId))).get();
  }

  /// Get sale with items (joined data)
  Future<Map<String, dynamic>> getSaleWithItems(String saleId) async {
    final sale = await getSaleById(saleId);
    if (sale == null) return {};

    final items = await getSaleItems(saleId);

    // Get product details for each item
    final itemsWithProducts = <Map<String, dynamic>>[];
    for (final item in items) {
      final product = await (_database.select(
        _database.products,
      )..where((p) => p.id.equals(item.productId))).getSingleOrNull();

      itemsWithProducts.add({'item': item, 'product': product});
    }

    return {'sale': sale, 'items': itemsWithProducts};
  }

  /// Create new sale with items
  Future<String> createSale({
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
    String status = 'completed',
    String? notes,
    DateTime? saleDate,
    required List<Map<String, dynamic>> items,
  }) async {
    final saleId = _uuid.v4();
    final now = DateTime.now();

    return await _database.transaction(() async {
      // Create the sale
      final sale = SalesCompanion(
        id: Value(saleId),
        warehouseId: Value(warehouseId),
        userId: Value(userId),
        customerName: Value(customerName),
        customerEmail: Value(customerEmail),
        customerPhone: Value(customerPhone),
        subtotal: Value(subtotal),
        taxAmount: Value(taxAmount),
        discountAmount: Value(discountAmount),
        totalAmount: Value(totalAmount),
        paymentMethod: Value(paymentMethod),
        status: Value(status),
        notes: Value(notes),
        saleDate: Value(saleDate ?? now),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database.into(_database.sales).insert(sale);

      // Create sale items
      for (final itemData in items) {
        // Validate item data
        final productId = itemData['productId'] as String?;
        final quantity = itemData['quantity'] as int?;
        final unitPrice = itemData['unitPrice'] as double?;
        final totalPrice = itemData['totalPrice'] as double?;

        if (productId == null ||
            quantity == null ||
            unitPrice == null ||
            totalPrice == null) {
          throw Exception(
            'Invalid item data: productId=$productId, quantity=$quantity, unitPrice=$unitPrice, totalPrice=$totalPrice',
          );
        }

        final itemId = _uuid.v4();
        final saleItem = SaleItemsCompanion(
          id: Value(itemId),
          saleId: Value(saleId),
          productId: Value(productId),
          quantity: Value(quantity),
          unitPrice: Value(unitPrice),
          totalPrice: Value(totalPrice),
          createdAt: Value(now),
        );

        await _database.into(_database.saleItems).insert(saleItem);

        // Validate stock availability before updating
        final product = await (_database.select(
          _database.products,
        )..where((p) => p.id.equals(productId))).getSingleOrNull();

        if (product == null) {
          throw Exception('Producto no encontrado: $productId');
        }

        if (product.quantity < quantity) {
          throw Exception(
            'Stock insuficiente para ${product.name}. Disponible: ${product.quantity}, Solicitado: $quantity',
          );
        }

        // Update product stock (create inventory movement)
        await _updateProductStock(
          productId: productId,
          warehouseId: warehouseId,
          userId: userId,
          quantity: -quantity, // Negative for sale
          reason: 'Venta #$saleId',
        );
      }

      return saleId;
    });
  }

  /// Update product stock and create inventory movement
  Future<void> _updateProductStock({
    required String productId,
    required String warehouseId,
    required String userId,
    required int quantity,
    required String reason,
  }) async {
    // Get current product
    final product = await (_database.select(
      _database.products,
    )..where((p) => p.id.equals(productId))).getSingleOrNull();

    if (product == null) return;

    final previousStock = product.quantity;
    final newStock = previousStock + quantity; // quantity is negative for sales

    // Update product stock
    await (_database.update(
      _database.products,
    )..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        quantity: Value(newStock),
        updatedAt: Value(DateTime.now()),
        lastSyncAt: const Value(null), // Mark as needing sync
      ),
    );

    // Create inventory movement record
    final movementId = _uuid.v4();
    final movement = InventoryMovementsCompanion(
      id: Value(movementId),
      productId: Value(productId),
      warehouseId: Value(warehouseId),
      userId: Value(userId),
      type: Value('out'),
      quantity: Value(quantity.abs()), // Store as positive number
      previousStock: Value(previousStock),
      newStock: Value(newStock),
      reason: Value(reason),
      createdAt: Value(DateTime.now()),
    );

    await _database.into(_database.inventoryMovements).insert(movement);
  }

  /// Get sales summary for dashboard
  Future<Map<String, dynamic>> getSalesSummary({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _database.select(_database.sales);

    if (warehouseId != null) {
      query = query..where((s) => s.warehouseId.equals(warehouseId));
    }

    if (startDate != null && endDate != null) {
      query = query
        ..where((s) => s.saleDate.isBetweenValues(startDate, endDate));
    }

    final sales = await query.get();

    final totalSales = sales.length;
    final totalRevenue = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final averageSale = totalSales > 0 ? totalRevenue / totalSales : 0.0;

    return {
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'averageSale': averageSale,
      'salesByStatus': _groupSalesByStatus(sales),
      'salesByPaymentMethod': _groupSalesByPaymentMethod(sales),
    };
  }

  Map<String, int> _groupSalesByStatus(List<Sale> sales) {
    final Map<String, int> grouped = {};
    for (final sale in sales) {
      grouped[sale.status] = (grouped[sale.status] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, int> _groupSalesByPaymentMethod(List<Sale> sales) {
    final Map<String, int> grouped = {};
    for (final sale in sales) {
      grouped[sale.paymentMethod] = (grouped[sale.paymentMethod] ?? 0) + 1;
    }
    return grouped;
  }

  /// Mark sale as synced
  Future<void> markAsSynced(String saleId) async {
    await (_database.update(_database.sales)..where((s) => s.id.equals(saleId)))
        .write(SalesCompanion(lastSyncAt: Value(DateTime.now())));
  }

  /// Get unsynced sales
  Future<List<Sale>> getUnsyncedSales() async {
    return await (_database.select(
      _database.sales,
    )..where((s) => s.lastSyncAt.isNull())).get();
  }

  /// Delete sale (and its items)
  Future<bool> deleteSale(String saleId) async {
    return await _database.transaction(() async {
      // Delete sale items first
      await (_database.delete(
        _database.saleItems,
      )..where((si) => si.saleId.equals(saleId))).go();

      // Delete the sale
      final salesDeleted = await (_database.delete(
        _database.sales,
      )..where((s) => s.id.equals(saleId))).go();

      return salesDeleted > 0;
    });
  }

  /// Upsert sale from server data
  Future<void> upsertSaleFromServer(Map<String, dynamic> data) async {
    final existing = await getSaleById(data['id']);

    if (existing == null) {
      // Create new sale
      await _database
          .into(_database.sales)
          .insert(
            SalesCompanion(
              id: Value(data['id']),
              warehouseId: Value(data['warehouse_id']),
              userId: Value(data['user_id']),
              customerName: Value(data['customer_name']),
              customerEmail: Value(data['customer_email']),
              customerPhone: Value(data['customer_phone']),
              subtotal: Value(data['subtotal']?.toDouble() ?? 0.0),
              taxAmount: Value(data['tax_amount']?.toDouble() ?? 0.0),
              discountAmount: Value(data['discount_amount']?.toDouble() ?? 0.0),
              totalAmount: Value(data['total_amount']?.toDouble() ?? 0.0),
              paymentMethod: Value(data['payment_method']),
              status: Value(data['status'] ?? 'completed'),
              notes: Value(data['notes']),
              saleDate: Value(DateTime.parse(data['sale_date'])),
              createdAt: Value(DateTime.parse(data['created_at'])),
              updatedAt: Value(DateTime.parse(data['updated_at'])),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
    } else {
      // Update existing if server version is newer
      final serverUpdated = DateTime.parse(data['updated_at']);
      if (serverUpdated.isAfter(existing.updatedAt)) {
        await (_database.update(
          _database.sales,
        )..where((s) => s.id.equals(data['id']))).write(
          SalesCompanion(
            warehouseId: Value(data['warehouse_id']),
            userId: Value(data['user_id']),
            customerName: Value(data['customer_name']),
            customerEmail: Value(data['customer_email']),
            customerPhone: Value(data['customer_phone']),
            subtotal: Value(data['subtotal']?.toDouble() ?? 0.0),
            taxAmount: Value(data['tax_amount']?.toDouble() ?? 0.0),
            discountAmount: Value(data['discount_amount']?.toDouble() ?? 0.0),
            totalAmount: Value(data['total_amount']?.toDouble() ?? 0.0),
            paymentMethod: Value(data['payment_method']),
            status: Value(data['status'] ?? 'completed'),
            notes: Value(data['notes']),
            saleDate: Value(DateTime.parse(data['sale_date'])),
            updatedAt: Value(DateTime.parse(data['updated_at'])),
            lastSyncAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  /// Upsert sale item from server data
  Future<void> upsertSaleItemFromServer(Map<String, dynamic> data) async {
    final existing = await (_database.select(
      _database.saleItems,
    )..where((si) => si.id.equals(data['id']))).getSingleOrNull();

    if (existing == null) {
      // Create new sale item
      await _database
          .into(_database.saleItems)
          .insert(
            SaleItemsCompanion(
              id: Value(data['id']),
              saleId: Value(data['sale_id']),
              productId: Value(data['product_id']),
              quantity: Value(data['quantity']),
              unitPrice: Value(data['unit_price']?.toDouble() ?? 0.0),
              totalPrice: Value(data['total_price']?.toDouble() ?? 0.0),
              createdAt: Value(DateTime.parse(data['created_at'])),
            ),
          );
    }
  }
}
