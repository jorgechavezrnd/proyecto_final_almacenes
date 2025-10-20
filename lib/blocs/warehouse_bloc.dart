import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../database/database.dart';
import '../repositories/inventory_repository.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class WarehouseEvent extends Equatable {
  const WarehouseEvent();

  @override
  List<Object?> get props => [];
}

class LoadWarehouses extends WarehouseEvent {
  const LoadWarehouses();
}

class RefreshWarehouses extends WarehouseEvent {
  const RefreshWarehouses();
}

class CreateWarehouse extends WarehouseEvent {
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;

  const CreateWarehouse({
    required this.name,
    this.description,
    this.address,
    this.city,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [name, description, address, city, phone, email];
}

class UpdateWarehouse extends WarehouseEvent {
  final String id;
  final String? name;
  final String? description;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final bool? isActive;

  const UpdateWarehouse({
    required this.id,
    this.name,
    this.description,
    this.address,
    this.city,
    this.phone,
    this.email,
    this.isActive,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    address,
    city,
    phone,
    email,
    isActive,
  ];
}

class DeleteWarehouse extends WarehouseEvent {
  final String id;

  const DeleteWarehouse(this.id);

  @override
  List<Object> get props => [id];
}

class SyncWarehouses extends WarehouseEvent {
  const SyncWarehouses();
}

// ============================================================================
// STATES
// ============================================================================

abstract class WarehouseState extends Equatable {
  const WarehouseState();

  @override
  List<Object?> get props => [];
}

class WarehouseInitial extends WarehouseState {
  const WarehouseInitial();
}

class WarehouseLoading extends WarehouseState {
  const WarehouseLoading();
}

class WarehouseLoaded extends WarehouseState {
  final List<Warehouse> warehouses;
  final bool hasPendingSync;

  const WarehouseLoaded({
    required this.warehouses,
    this.hasPendingSync = false,
  });

  @override
  List<Object?> get props => [warehouses, hasPendingSync];

  WarehouseLoaded copyWith({
    List<Warehouse>? warehouses,
    bool? hasPendingSync,
  }) {
    return WarehouseLoaded(
      warehouses: warehouses ?? this.warehouses,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
    );
  }
}

class WarehouseError extends WarehouseState {
  final String message;

  const WarehouseError(this.message);

  @override
  List<Object> get props => [message];
}

class WarehouseOperationSuccess extends WarehouseState {
  final String message;
  final List<Warehouse> warehouses;

  const WarehouseOperationSuccess({
    required this.message,
    required this.warehouses,
  });

  @override
  List<Object> get props => [message, warehouses];
}

class WarehouseSyncing extends WarehouseState {
  final List<Warehouse> warehouses;

  const WarehouseSyncing(this.warehouses);

  @override
  List<Object> get props => [warehouses];
}

// ============================================================================
// BLOC
// ============================================================================

class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  final InventoryRepository _repository;

  WarehouseBloc({required InventoryRepository repository})
    : _repository = repository,
      super(const WarehouseInitial()) {
    on<LoadWarehouses>(_onLoadWarehouses);
    on<RefreshWarehouses>(_onRefreshWarehouses);
    on<CreateWarehouse>(_onCreateWarehouse);
    on<UpdateWarehouse>(_onUpdateWarehouse);
    on<DeleteWarehouse>(_onDeleteWarehouse);
    on<SyncWarehouses>(_onSyncWarehouses);
  }

  Future<void> _onLoadWarehouses(
    LoadWarehouses event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      emit(const WarehouseLoading());

      final warehouses = await _repository.getAllWarehouses();
      final hasPendingSync = await _repository.hasPendingSync();

      emit(
        WarehouseLoaded(warehouses: warehouses, hasPendingSync: hasPendingSync),
      );
    } catch (e) {
      emit(WarehouseError('Error loading warehouses: $e'));
    }
  }

  Future<void> _onRefreshWarehouses(
    RefreshWarehouses event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      // Don't show loading for refresh
      final warehouses = await _repository.getAllWarehouses();
      final hasPendingSync = await _repository.hasPendingSync();

      emit(
        WarehouseLoaded(warehouses: warehouses, hasPendingSync: hasPendingSync),
      );
    } catch (e) {
      // Keep current state on refresh error
      if (state is WarehouseLoaded) {
        final currentState = state as WarehouseLoaded;
        emit(currentState.copyWith(hasPendingSync: true));
      } else {
        emit(WarehouseError('Error refreshing warehouses: $e'));
      }
    }
  }

  Future<void> _onCreateWarehouse(
    CreateWarehouse event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      final result = await _repository.createWarehouse(
        name: event.name,
        description: event.description,
        address: event.address,
        city: event.city,
        phone: event.phone,
        email: event.email,
      );

      if (result.isSuccess) {
        final warehouses = await _repository.getAllWarehouses();
        emit(
          WarehouseOperationSuccess(
            message: 'Warehouse created successfully',
            warehouses: warehouses,
          ),
        );
      } else {
        emit(WarehouseError(result.error ?? 'Failed to create warehouse'));
      }
    } catch (e) {
      emit(WarehouseError('Error creating warehouse: $e'));
    }
  }

  Future<void> _onUpdateWarehouse(
    UpdateWarehouse event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      final result = await _repository.updateWarehouse(
        id: event.id,
        name: event.name,
        description: event.description,
        address: event.address,
        city: event.city,
        phone: event.phone,
        email: event.email,
        isActive: event.isActive,
      );

      if (result.isSuccess) {
        final warehouses = await _repository.getAllWarehouses();
        emit(
          WarehouseOperationSuccess(
            message: 'Warehouse updated successfully',
            warehouses: warehouses,
          ),
        );
      } else {
        emit(WarehouseError(result.error ?? 'Failed to update warehouse'));
      }
    } catch (e) {
      emit(WarehouseError('Error updating warehouse: $e'));
    }
  }

  Future<void> _onDeleteWarehouse(
    DeleteWarehouse event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      final result = await _repository.deleteWarehouse(event.id);

      if (result.isSuccess) {
        final warehouses = await _repository.getAllWarehouses();
        emit(
          WarehouseOperationSuccess(
            message: 'Warehouse deleted successfully',
            warehouses: warehouses,
          ),
        );
      } else {
        emit(WarehouseError(result.error ?? 'Failed to delete warehouse'));
      }
    } catch (e) {
      emit(WarehouseError('Error deleting warehouse: $e'));
    }
  }

  Future<void> _onSyncWarehouses(
    SyncWarehouses event,
    Emitter<WarehouseState> emit,
  ) async {
    try {
      if (state is WarehouseLoaded) {
        final currentState = state as WarehouseLoaded;
        emit(WarehouseSyncing(currentState.warehouses));
      }

      await _repository.syncToServer();

      final warehouses = await _repository.getAllWarehouses();
      emit(WarehouseLoaded(warehouses: warehouses, hasPendingSync: false));
    } catch (e) {
      if (state is WarehouseSyncing) {
        final currentState = state as WarehouseSyncing;
        emit(
          WarehouseLoaded(
            warehouses: currentState.warehouses,
            hasPendingSync: true,
          ),
        );
      }
      emit(WarehouseError('Sync failed: $e'));
    }
  }
}
