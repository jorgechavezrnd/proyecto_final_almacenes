import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import '../../blocs/reports_bloc.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  AdminSalesReportLoaded? _lastReportState;
  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_ES',
    symbol: 'Bs.',
    decimalDigits: 2,
  );
  final _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Load reports after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  void _loadReports() {
    try {
      final reportsBloc = context.read<ReportsBloc>();
      reportsBloc.add(
        LoadAdminSalesReport(startDate: _startDate, endDate: _endDate),
      );
    } catch (e) {
      print('Error loading admin reports: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Seleccionar rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldStartHintText: 'Fecha inicio',
      fieldEndHintText: 'Fecha fin',
      fieldStartLabelText: 'Fecha inicio',
      fieldEndLabelText: 'Fecha fin',
      saveText: 'Aceptar',
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReports();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadReports();
  }

  Future<void> _generatePdf(AdminSalesReportLoaded state) async {
    // Guardar el estado antes de generar PDF
    _lastReportState = state;
    
    context.read<ReportsBloc>().add(
      GenerateAdminSalesReportPdf(
        salesByUser: state.salesByUser,
        startDate: state.startDate,
        endDate: state.endDate,
      ),
    );
  }

  Future<void> _printPdf(Uint8List pdfBytes) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      // Después de imprimir, restaurar el estado anterior
      _restorePreviousState();
    } catch (e) {
      print('Error printing PDF: $e');
      // Si hay error, también restaurar el estado
      _restorePreviousState();
    }
  }

  void _restorePreviousState() {
    if (_lastReportState != null) {
      // Usar un evento especial para restaurar el estado
      context.read<ReportsBloc>().add(
        RestoreAdminSalesReportView(
          salesByUser: _lastReportState!.salesByUser,
          startDate: _lastReportState!.startDate,
          endDate: _lastReportState!.endDate,
        ),
      );
    } else {
      // Si no hay estado guardado, recargar
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Administrativos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Actualizar reportes',
          ),
        ],
      ),
      body: BlocConsumer<ReportsBloc, ReportsState>(
        listener: (context, state) {
          if (state is ReportPdfGenerated) {
            // Solo imprimir el PDF, el estado ya fue guardado en _generatePdf
            _printPdf(state.pdfBytes);
          } else if (state is ReportsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is ReportsAccessDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildFilterSection(),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildContent(state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${_dateFormatter.format(_startDate!)} - ${_dateFormatter.format(_endDate!)}'
                          : 'Seleccionar fechas',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_startDate != null || _endDate != null)
                  IconButton(
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Limpiar filtro',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ReportsState state) {
    if (state is ReportsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando reportes administrativos...'),
          ],
        ),
      );
    }

    if (state is ReportsAccessDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Acceso Denegado',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (state is AdminSalesReportLoaded) {
      return _buildReportContent(state);
    }

    if (state is ReportsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar reportes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Show last report if available during PDF generation
    if (_lastReportState != null) {
      return _buildReportContent(_lastReportState!);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Reportes Administrativos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los reportes se cargarán automáticamente',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(AdminSalesReportLoaded state) {
    final totalSales = state.salesByUser.values
        .expand((sales) => sales)
        .length;
    final totalAmount = state.salesByUser.values
        .expand((sales) => sales)
        .fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);

    return Column(
      children: [
        _buildSummaryCards(totalSales, totalAmount, state.salesByUser.length),
        const SizedBox(height: 16),
        Expanded(
          child: _buildSalesByUserList(state.salesByUser),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(state),
      ],
    );
  }

  Widget _buildSummaryCards(int totalSales, double totalAmount, int totalUsers) {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: 32,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Ventas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$totalSales',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 32,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Ingresos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currencyFormatter.format(totalAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.people,
                    size: 32,
                    color: Colors.purple.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usuarios Activos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$totalUsers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesByUserList(Map<String, List<dynamic>> salesByUser) {
    if (salesByUser.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ventas en el período seleccionado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: salesByUser.length,
      itemBuilder: (context, index) {
        final userName = salesByUser.keys.elementAt(index);
        final sales = salesByUser[userName]!;
        final userTotalAmount = sales.fold<double>(
          0.0,
          (sum, sale) => sum + sale.totalAmount,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${sales.length} ventas - ${_currencyFormatter.format(userTotalAmount)}',
            ),
            children: sales.map<Widget>((sale) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: Icon(
                  Icons.receipt,
                  color: Colors.grey.shade600,
                ),
                title: Text(
                  'Venta #${sale.id}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _dateFormatter.format(sale.saleDate),
                ),
                trailing: Text(
                  _currencyFormatter.format(sale.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(AdminSalesReportLoaded state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _generatePdf(state),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Generar PDF'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}