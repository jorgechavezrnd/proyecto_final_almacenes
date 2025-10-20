import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../database/database.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/auth_repository.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSales extends SalesEvent {
  const LoadSales();
}

class LoadSalesByDateRange extends SalesEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadSalesByDateRange({required this.startDate, required this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class LoadSalesByWarehouse extends SalesEvent {
  final String warehouseId;

  const LoadSalesByWarehouse(this.warehouseId);

  @override
  List<Object?> get props => [warehouseId];
}

class LoadSalesByUser extends SalesEvent {
  final String userId;

  const LoadSalesByUser(this.userId);

  @override
  List<Object?> get props => [userId];
}

class CreateSale extends SalesEvent {
  final String warehouseId;
  final String userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final String? notes;
  final List<Map<String, dynamic>> items;

  const CreateSale({
    required this.warehouseId,
    required this.userId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    required this.subtotal,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.notes,
    required this.items,
  });

  @override
  List<Object?> get props => [
    warehouseId,
    userId,
    customerName,
    customerEmail,
    customerPhone,
    subtotal,
    taxAmount,
    discountAmount,
    totalAmount,
    paymentMethod,
    notes,
    items,
  ];
}

class LoadSaleDetails extends SalesEvent {
  final String saleId;

  const LoadSaleDetails(this.saleId);

  @override
  List<Object?> get props => [saleId];
}

class DeleteSale extends SalesEvent {
  final String saleId;

  const DeleteSale(this.saleId);

  @override
  List<Object?> get props => [saleId];
}

class RefreshSales extends SalesEvent {
  const RefreshSales();
}

class SyncSales extends SalesEvent {
  const SyncSales();
}

class LoadSalesSummary extends SalesEvent {
  final String? warehouseId;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadSalesSummary({this.warehouseId, this.startDate, this.endDate});

  @override
  List<Object?> get props => [warehouseId, startDate, endDate];
}

// ============================================================================
// STATES
// ============================================================================

abstract class SalesState extends Equatable {
  const SalesState();

  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {
  const SalesInitial();
}

class SalesLoading extends SalesState {
  const SalesLoading();
}

class SalesLoaded extends SalesState {
  final List<Sale> sales;

  const SalesLoaded(this.sales);

  @override
  List<Object?> get props => [sales];
}

class SaleDetailsLoaded extends SalesState {
  final Map<String, dynamic> saleWithItems;

  const SaleDetailsLoaded(this.saleWithItems);

  @override
  List<Object?> get props => [saleWithItems];
}

class SalesSummaryLoaded extends SalesState {
  final Map<String, dynamic> summary;

  const SalesSummaryLoaded(this.summary);

  @override
  List<Object?> get props => [summary];
}

class SalesOperationSuccess extends SalesState {
  final String message;
  final List<Sale> sales;

  const SalesOperationSuccess({required this.message, required this.sales});

  @override
  List<Object?> get props => [message, sales];
}

class SalesError extends SalesState {
  final String message;

  const SalesError(this.message);

  @override
  List<Object?> get props => [message];
}

class SalesSync extends SalesState {
  final String message;

  const SalesSync(this.message);

  @override
  List<Object?> get props => [message];
}

// ============================================================================
// BLOC
// ============================================================================

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final InventoryRepository _repository;
  final AuthRepository _authRepository;

  SalesBloc(this._repository, this._authRepository)
    : super(const SalesInitial()) {
    on<LoadSales>(_onLoadSales);
    on<LoadSalesByDateRange>(_onLoadSalesByDateRange);
    on<LoadSalesByWarehouse>(_onLoadSalesByWarehouse);
    on<LoadSalesByUser>(_onLoadSalesByUser);
    on<CreateSale>(_onCreateSale);
    on<LoadSaleDetails>(_onLoadSaleDetails);
    on<DeleteSale>(_onDeleteSale);
    on<RefreshSales>(_onRefreshSales);
    on<SyncSales>(_onSyncSales);
    on<LoadSalesSummary>(_onLoadSalesSummary);
  }

  Future<void> _onLoadSales(LoadSales event, Emitter<SalesState> emit) async {
    try {
      emit(const SalesLoading());

      // Get current user and role
      final currentUser = await _authRepository.getCurrentUser();
      final userRole = await _authRepository.getUserRole();

      List<Sale> sales;

      // If user is admin, show all sales. Otherwise, show only user's sales
      if (userRole?.toLowerCase() == 'admin') {
        sales = await _repository.getAllSales();
      } else if (currentUser != null) {
        sales = await _repository.getSalesByUser(currentUser.id);
      } else {
        emit(const SalesError('Usuario no autenticado'));
        return;
      }

      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Error loading sales: $e'));
    }
  }

  Future<void> _onLoadSalesByDateRange(
    LoadSalesByDateRange event,
    Emitter<SalesState> emit,
  ) async {
    try {
      emit(const SalesLoading());

      // Get current user and role
      final currentUser = await _authRepository.getCurrentUser();
      final userRole = await _authRepository.getUserRole();

      List<Sale> sales;

      // If user is admin, show all sales. Otherwise, show only user's sales
      if (userRole?.toLowerCase() == 'admin') {
        sales = await _repository.getSalesByDateRange(
          event.startDate,
          event.endDate,
        );
      } else if (currentUser != null) {
        sales = await _repository.getSalesByUserAndDateRange(
          currentUser.id,
          event.startDate,
          event.endDate,
        );
      } else {
        emit(const SalesError('Usuario no autenticado'));
        return;
      }

      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Error loading sales by date range: $e'));
    }
  }

  Future<void> _onLoadSalesByWarehouse(
    LoadSalesByWarehouse event,
    Emitter<SalesState> emit,
  ) async {
    try {
      emit(const SalesLoading());
      final sales = await _repository.getSalesByWarehouse(event.warehouseId);
      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Error loading sales by warehouse: $e'));
    }
  }

  Future<void> _onLoadSalesByUser(
    LoadSalesByUser event,
    Emitter<SalesState> emit,
  ) async {
    try {
      emit(const SalesLoading());
      final sales = await _repository.getSalesByUser(event.userId);
      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Error loading sales by user: $e'));
    }
  }

  Future<void> _onCreateSale(CreateSale event, Emitter<SalesState> emit) async {
    try {
      emit(const SalesLoading());
      final result = await _repository.createSale(
        warehouseId: event.warehouseId,
        userId: event.userId,
        customerName: event.customerName,
        customerEmail: event.customerEmail,
        customerPhone: event.customerPhone,
        subtotal: event.subtotal,
        taxAmount: event.taxAmount,
        discountAmount: event.discountAmount,
        totalAmount: event.totalAmount,
        paymentMethod: event.paymentMethod,
        notes: event.notes,
        items: event.items,
      );

      if (result.isSuccess) {
        final sales = await _repository.getAllSales();
        emit(
          SalesOperationSuccess(
            message: 'Sale created successfully',
            sales: sales,
          ),
        );
      } else {
        emit(SalesError(result.error ?? 'Failed to create sale'));
      }
    } catch (e) {
      emit(SalesError('Error creating sale: $e'));
    }
  }

  Future<void> _onLoadSaleDetails(
    LoadSaleDetails event,
    Emitter<SalesState> emit,
  ) async {
    try {
      emit(const SalesLoading());
      final saleWithItems = await _repository.getSaleWithItems(event.saleId);
      emit(SaleDetailsLoaded(saleWithItems));
    } catch (e) {
      emit(SalesError('Error loading sale details: $e'));
    }
  }

  Future<void> _onDeleteSale(DeleteSale event, Emitter<SalesState> emit) async {
    try {
      emit(const SalesLoading());
      final result = await _repository.deleteSale(event.saleId);

      if (result.isSuccess) {
        final sales = await _repository.getAllSales();
        emit(
          SalesOperationSuccess(
            message: 'Sale deleted successfully',
            sales: sales,
          ),
        );
      } else {
        emit(SalesError(result.error ?? 'Failed to delete sale'));
      }
    } catch (e) {
      emit(SalesError('Error deleting sale: $e'));
    }
  }

  Future<void> _onRefreshSales(
    RefreshSales event,
    Emitter<SalesState> emit,
  ) async {
    try {
      // Try to sync first
      await _repository.syncSales();

      // Then load fresh data
      final sales = await _repository.getAllSales();
      emit(SalesLoaded(sales));
    } catch (e) {
      // Even if sync fails, load local data
      try {
        final sales = await _repository.getAllSales();
        emit(SalesLoaded(sales));
      } catch (localError) {
        emit(SalesError('Error refreshing sales: $localError'));
      }
    }
  }

  Future<void> _onSyncSales(SyncSales event, Emitter<SalesState> emit) async {
    try {
      await _repository.syncSales();
      emit(const SalesSync('Sales synced successfully'));

      // Reload data after sync
      final sales = await _repository.getAllSales();
      emit(SalesLoaded(sales));
    } catch (e) {
      emit(SalesError('Sync failed: $e'));
    }
  }

  Future<void> _onLoadSalesSummary(
    LoadSalesSummary event,
    Emitter<SalesState> emit,
  ) async {
    try {
      emit(const SalesLoading());
      final summary = await _repository.getSalesSummary(
        warehouseId: event.warehouseId,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(SalesSummaryLoaded(summary));
    } catch (e) {
      emit(SalesError('Error loading sales summary: $e'));
    }
  }
}
