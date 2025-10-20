import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

/// Data Access Object for Warehouse operations
class WarehouseDao {
  final AppDatabase _database;
  final _uuid = const Uuid();

  WarehouseDao(this._database);

  /// Get all warehouses
  Future<List<Warehouse>> getAllWarehouses() async {
    return await _database.select(_database.warehouses).get();
  }

  /// Get active warehouses only
  Future<List<Warehouse>> getActiveWarehouses() async {
    return await (_database.select(
      _database.warehouses,
    )..where((w) => w.isActive.equals(true))).get();
  }

  /// Get warehouse by ID
  Future<Warehouse?> getWarehouseById(String id) async {
    return await (_database.select(
      _database.warehouses,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  /// Search warehouses by name
  Future<List<Warehouse>> searchWarehouses(String query) async {
    return await (_database.select(_database.warehouses)
          ..where((w) => w.name.contains(query) | w.description.contains(query))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  /// Create new warehouse
  Future<String> createWarehouse({
    required String name,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? email,
  }) async {
    final id = _uuid.v4();
    final warehouse = WarehousesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      address: Value(address),
      city: Value(city),
      phone: Value(phone),
      email: Value(email),
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _database.into(_database.warehouses).insert(warehouse);
    return id;
  }

  /// Update warehouse
  Future<bool> updateWarehouse({
    required String id,
    String? name,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? email,
    bool? isActive,
  }) async {
    final updateCompanion = WarehousesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      address: address != null ? Value(address) : const Value.absent(),
      city: city != null ? Value(city) : const Value.absent(),
      phone: phone != null ? Value(phone) : const Value.absent(),
      email: email != null ? Value(email) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    final rowsAffected = await (_database.update(
      _database.warehouses,
    )..where((w) => w.id.equals(id))).write(updateCompanion);

    return rowsAffected > 0;
  }

  /// Soft delete warehouse (mark as inactive)
  Future<bool> deactivateWarehouse(String id) async {
    return await updateWarehouse(id: id, isActive: false);
  }

  /// Hard delete warehouse
  Future<bool> deleteWarehouse(String id) async {
    final rowsAffected = await (_database.delete(
      _database.warehouses,
    )..where((w) => w.id.equals(id))).go();

    return rowsAffected > 0;
  }

  /// Get warehouse statistics
  Future<Map<String, dynamic>> getWarehouseStats(String warehouseId) async {
    // Get total products
    final totalProducts =
        await (_database.selectOnly(_database.products)
              ..addColumns([_database.products.id.count()])
              ..where(
                _database.products.warehouseId.equals(warehouseId) &
                    _database.products.isActive.equals(true),
              ))
            .map((row) => row.read(_database.products.id.count()) ?? 0)
            .getSingle();

    // Get products for calculations
    final products =
        await (_database.select(_database.products)..where(
              (p) =>
                  p.warehouseId.equals(warehouseId) & p.isActive.equals(true),
            ))
            .get();

    // Calculate total stock value
    final totalStockValue = products.fold<double>(
      0.0,
      (sum, product) => sum + (product.quantity * product.cost),
    );

    // Get low stock products count
    final lowStockProducts = products
        .where((p) => p.quantity <= p.minStock)
        .length;

    return {
      'totalProducts': totalProducts,
      'totalStockValue': totalStockValue,
      'lowStockProducts': lowStockProducts,
    };
  }

  /// Mark warehouse as synced
  Future<void> markAsSynced(String id) async {
    await (_database.update(_database.warehouses)
          ..where((w) => w.id.equals(id)))
        .write(WarehousesCompanion(lastSyncAt: Value(DateTime.now())));
  }

  /// Get warehouses that need sync (modified after last sync)
  Future<List<Warehouse>> getWarehousesNeedingSync() async {
    return await (_database.select(_database.warehouses)..where(
          (w) => w.lastSyncAt.isNull() | w.updatedAt.isBiggerThan(w.lastSyncAt),
        ))
        .get();
  }
}
