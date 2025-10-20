import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/auth_repository.dart';
import '../database/database.dart';
import '../services/pdf_report_service.dart';
import 'dart:typed_data';

// Events
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserSalesReport extends ReportsEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadUserSalesReport({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class GenerateSalesReportPdf extends ReportsEvent {
  final List<Sale> sales;
  final DateTime? startDate;
  final DateTime? endDate;

  const GenerateSalesReportPdf({
    required this.sales,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [sales, startDate, endDate];
}

class RestoreSalesReportView extends ReportsEvent {
  final List<Sale> sales;
  final double totalAmount;
  final int totalSales;
  final DateTime? startDate;
  final DateTime? endDate;
  final String userName;

  const RestoreSalesReportView({
    required this.sales,
    required this.totalAmount,
    required this.totalSales,
    this.startDate,
    this.endDate,
    required this.userName,
  });

  @override
  List<Object?> get props => [
    sales,
    totalAmount,
    totalSales,
    startDate,
    endDate,
    userName,
  ];
}

class LoadAdminSalesReport extends ReportsEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadAdminSalesReport({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class GenerateAdminSalesReportPdf extends ReportsEvent {
  final Map<String, List<Sale>> salesByUser;
  final DateTime? startDate;
  final DateTime? endDate;

  const GenerateAdminSalesReportPdf({
    required this.salesByUser,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [salesByUser, startDate, endDate];
}

class RestoreAdminSalesReportView extends ReportsEvent {
  final Map<String, List<Sale>> salesByUser;
  final DateTime? startDate;
  final DateTime? endDate;

  const RestoreAdminSalesReportView({
    required this.salesByUser,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [salesByUser, startDate, endDate];
}

// States
abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsAccessDenied extends ReportsState {
  final String message;

  const ReportsAccessDenied(this.message);

  @override
  List<Object?> get props => [message];
}

class UserSalesReportLoaded extends ReportsState {
  final List<Sale> sales;
  final double totalAmount;
  final int totalSales;
  final DateTime? startDate;
  final DateTime? endDate;
  final String userName;

  const UserSalesReportLoaded({
    required this.sales,
    required this.totalAmount,
    required this.totalSales,
    this.startDate,
    this.endDate,
    required this.userName,
  });

  @override
  List<Object?> get props => [
    sales,
    totalAmount,
    totalSales,
    startDate,
    endDate,
    userName,
  ];
}

class AdminSalesReportLoaded extends ReportsState {
  final Map<String, List<Sale>> salesByUser;
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminSalesReportLoaded({
    required this.salesByUser,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [salesByUser, startDate, endDate];
}

class ReportPdfGenerated extends ReportsState {
  final Uint8List pdfBytes;
  final String fileName;

  const ReportPdfGenerated({required this.pdfBytes, required this.fileName});

  @override
  List<Object?> get props => [pdfBytes, fileName];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final InventoryRepository _repository;
  final AuthRepository _authRepository;

  ReportsBloc({
    required InventoryRepository repository,
    required AuthRepository authRepository,
  }) : _repository = repository,
       _authRepository = authRepository,
       super(ReportsInitial()) {
    on<LoadUserSalesReport>(_onLoadUserSalesReport);
    on<GenerateSalesReportPdf>(_onGenerateSalesReportPdf);
    on<RestoreSalesReportView>(_onRestoreSalesReportView);
    on<LoadAdminSalesReport>(_onLoadAdminSalesReport);
    on<GenerateAdminSalesReportPdf>(_onGenerateAdminSalesReportPdf);
    on<RestoreAdminSalesReportView>(_onRestoreAdminSalesReportView);
  }

  Future<void> _onLoadUserSalesReport(
    LoadUserSalesReport event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      emit(ReportsLoading());

      // Check user role - only non-admin users can generate reports
      final userRole = await _authRepository.getUserRole();
      if (userRole == null) {
        emit(const ReportsAccessDenied('Usuario no autenticado'));
        return;
      }

      if (userRole == 'admin') {
        emit(
          const ReportsAccessDenied(
            'Los administradores no pueden generar reportes de ventas. Solo usuarios regulares.',
          ),
        );
        return;
      }

      // Get current user ID
      final currentUser = await _authRepository.getCurrentUser();
      if (currentUser == null) {
        emit(const ReportsAccessDenied('Usuario no encontrado'));
        return;
      }

      // Get user sales in date range
      List<Sale> sales;
      if (event.startDate != null && event.endDate != null) {
        sales = await _repository.getSalesByUserAndDateRange(
          currentUser.id,
          event.startDate!,
          event.endDate!,
        );
      } else {
        sales = await _repository.getSalesByUser(currentUser.id);
      }

      // Calculate totals
      final totalAmount = sales.fold<double>(
        0.0,
        (sum, sale) => sum + sale.totalAmount,
      );

      final userName =
          currentUser.userMetadata?['full_name'] ??
          currentUser.email ??
          'Usuario';

      emit(
        UserSalesReportLoaded(
          sales: sales,
          totalAmount: totalAmount,
          totalSales: sales.length,
          startDate: event.startDate,
          endDate: event.endDate,
          userName: userName,
        ),
      );
    } catch (e) {
      emit(ReportsError('Error al cargar el reporte: $e'));
    }
  }

  Future<void> _onGenerateSalesReportPdf(
    GenerateSalesReportPdf event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      emit(ReportsLoading());

      // Check access again
      final userRole = await _authRepository.getUserRole();
      if (userRole == 'admin') {
        emit(
          const ReportsAccessDenied(
            'Los administradores no pueden generar reportes PDF.',
          ),
        );
        return;
      }

      final currentUser = await _authRepository.getCurrentUser();
      if (currentUser == null) {
        emit(const ReportsAccessDenied('Usuario no encontrado'));
        return;
      }

      // Generate PDF
      final pdfService = PdfReportService();
      final pdfBytes = await pdfService.generateSalesReport(
        sales: event.sales,
        userName:
            currentUser.userMetadata?['full_name'] ??
            currentUser.email ??
            'Usuario',
        startDate: event.startDate,
        endDate: event.endDate,
      );

      final fileName =
          'reporte_ventas_${DateTime.now().millisecondsSinceEpoch}.pdf';

      emit(ReportPdfGenerated(pdfBytes: pdfBytes, fileName: fileName));
    } catch (e) {
      emit(ReportsError('Error al generar PDF: $e'));
    }
  }

  Future<void> _onRestoreSalesReportView(
    RestoreSalesReportView event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      UserSalesReportLoaded(
        sales: event.sales,
        totalAmount: event.totalAmount,
        totalSales: event.totalSales,
        startDate: event.startDate,
        endDate: event.endDate,
        userName: event.userName,
      ),
    );
  }

  Future<void> _onLoadAdminSalesReport(
    LoadAdminSalesReport event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      emit(ReportsLoading());

      // Check user role - only admin users can generate admin reports
      final userRole = await _authRepository.getUserRole();
      if (userRole == null) {
        emit(const ReportsAccessDenied('Usuario no autenticado'));
        return;
      }

      if (userRole != 'admin') {
        emit(
          const ReportsAccessDenied(
            'Solo los administradores pueden acceder a reportes administrativos.',
          ),
        );
        return;
      }

      // Get all sales from all non-admin users
      Map<String, List<Sale>> salesByUser;
      if (event.startDate != null && event.endDate != null) {
        salesByUser = await _repository.getAllSalesByUserAndDateRange(
          event.startDate!,
          event.endDate!,
        );
      } else {
        salesByUser = await _repository.getAllSalesByUser();
      }

      emit(
        AdminSalesReportLoaded(
          salesByUser: salesByUser,
          startDate: event.startDate,
          endDate: event.endDate,
        ),
      );
    } catch (e) {
      emit(ReportsError('Error al cargar el reporte administrativo: $e'));
    }
  }

  Future<void> _onGenerateAdminSalesReportPdf(
    GenerateAdminSalesReportPdf event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      emit(ReportsLoading());

      // Check access again
      final userRole = await _authRepository.getUserRole();
      if (userRole != 'admin') {
        emit(
          const ReportsAccessDenied(
            'Solo los administradores pueden generar reportes PDF administrativos.',
          ),
        );
        return;
      }

      // Generate PDF
      final pdfService = PdfReportService();
      final pdfBytes = await pdfService.generateAdminSalesReport(
        salesByUser: event.salesByUser,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      final fileName =
          'reporte_admin_ventas_${DateTime.now().millisecondsSinceEpoch}.pdf';

      emit(ReportPdfGenerated(pdfBytes: pdfBytes, fileName: fileName));
    } catch (e) {
      emit(ReportsError('Error al generar PDF administrativo: $e'));
    }
  }

  Future<void> _onRestoreAdminSalesReportView(
    RestoreAdminSalesReportView event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      AdminSalesReportLoaded(
        salesByUser: event.salesByUser,
        startDate: event.startDate,
        endDate: event.endDate,
      ),
    );
  }
}
