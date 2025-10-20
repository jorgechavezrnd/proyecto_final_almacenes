import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// User session table for local storage
class UserSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  TextColumn get email => text()();
  TextColumn get role => text().nullable()();
  TextColumn get userMetadata => text().nullable()(); // JSON string
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Warehouses table for storing warehouse information
class Warehouses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Products table for storing product information
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get warehouseId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  RealColumn get cost => real().withDefault(const Constant(0.0))();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  IntColumn get maxStock => integer().nullable()();
  TextColumn get unit =>
      text().withDefault(const Constant('unit'))(); // unit, kg, lbs, etc
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inventory movements table for tracking stock changes
class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get warehouseId => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()(); // 'in', 'out', 'adjustment', 'transfer'
  IntColumn get quantity => integer()();
  IntColumn get previousStock => integer()();
  IntColumn get newStock => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sales table for storing sales transactions
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get warehouseId => text()();
  TextColumn get userId => text()();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerEmail => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod =>
      text()(); // 'cash', 'card', 'transfer', 'other'
  TextColumn get status => text().withDefault(
    const Constant('completed'),
  )(); // 'pending', 'completed', 'cancelled'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get saleDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sale items table for storing individual items in each sale
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get totalPrice => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main database class for the application
@DriftDatabase(
  tables: [
    UserSessions,
    Warehouses,
    Products,
    InventoryMovements,
    Sales,
    SaleItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle database migrations here
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_database.sqlite'));

    // For development: uncomment the next line to reset the database
    // if (await file.exists()) await file.delete();

    return NativeDatabase.createInBackground(file, logStatements: true);
  });
}

/// Helper function to reset database (for development only)
Future<void> resetDatabase() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'app_database.sqlite'));
  if (await file.exists()) {
    await file.delete();
  }
}
