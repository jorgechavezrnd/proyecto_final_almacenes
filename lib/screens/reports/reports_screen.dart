import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import '../../blocs/reports_bloc.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  UserSalesReportLoaded? _lastReportState;
  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_ES',
    symbol: 'Bs.',
    decimalDigits: 2,
  );
  final _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Load reports immediately
    _loadReports();
  }

  void _loadReports() {
    context.read<ReportsBloc>().add(
      LoadUserSalesReport(startDate: _startDate, endDate: _endDate),
    );
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
      saveText: 'Guardar',
      errorFormatText: 'Formato de fecha inválido',
      errorInvalidText: 'Fecha fuera del rango permitido',
      fieldStartHintText: 'Fecha de inicio',
      fieldEndHintText: 'Fecha de fin',
      fieldStartLabelText: 'Fecha de inicio',
      fieldEndLabelText: 'Fecha de fin',
    );

    if (picked != null) {
      setState(() {
        // Asegurar que la fecha de inicio sea a las 00:00:00
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        // Asegurar que la fecha de fin sea a las 23:59:59 para incluir todo el día
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      print(
        '🔍 DEBUG: Fechas seleccionadas - Inicio: $_startDate, Fin: $_endDate',
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Seleccionar rango de fechas',
          ),
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateFilter,
              tooltip: 'Limpiar filtro de fechas',
            ),
        ],
      ),
      body: BlocListener<ReportsBloc, ReportsState>(
        listener: (context, state) {
          if (state is ReportPdfGenerated) {
            _showPdfPreview(state.pdfBytes, state.fileName);
          } else if (state is ReportsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ReportsBloc, ReportsState>(
          builder: (context, state) {
            if (state is ReportsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ReportsAccessDenied) {
              return _buildAccessDenied(state.message);
            }

            if (state is UserSalesReportLoaded) {
              _lastReportState = state; // Store the last successful state
              return _buildReportView(state);
            }

            if (state is ReportPdfGenerated) {
              // Mostrar el último estado de datos mientras se genera el PDF
              if (_lastReportState != null) {
                return _buildReportView(_lastReportState!);
              }
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generando PDF...'),
                  ],
                ),
              );
            }

            if (state is ReportsError) {
              return _buildErrorView(state.message);
            }

            return const Center(child: Text('Cargando reportes...'));
          },
        ),
      ),
    );
  }

  Widget _buildAccessDenied(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Acceso Denegado',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text('Error', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReports,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportView(UserSalesReportLoaded state) {
    return Column(
      children: [
        // Date filter info
        if (_startDate != null || _endDate != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              'Período: ${_dateFormatter.format(_startDate!)} - ${_dateFormatter.format(_endDate!)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),

        // Summary cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Ventas',
                  state.totalSales.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Monto Total',
                  _currencyFormatter.format(state.totalAmount),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),

        // Generate PDF button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ReportsBloc>().add(
                  GenerateSalesReportPdf(
                    sales: state.sales,
                    startDate: state.startDate,
                    endDate: state.endDate,
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generar PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sales list
        Expanded(
          child: state.sales.isEmpty
              ? _buildEmptyState()
              : _buildSalesList(state.sales),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay ventas en el período seleccionado',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Cambia el rango de fechas o realiza algunas ventas',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList(List<dynamic> sales) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.receipt, color: Colors.white),
            ),
            title: Text(
              sale.customerName ?? 'Cliente general',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateFormatter.format(sale.saleDate)),
                Text('Método: ${_getPaymentMethodName(sale.paymentMethod)}'),
              ],
            ),
            trailing: Text(
              _currencyFormatter.format(sale.totalAmount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getPaymentMethodName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'qr':
        return 'QR';
      default:
        return paymentMethod;
    }
  }

  void _showPdfPreview(Uint8List pdfBytes, String fileName) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Vista Previa del Reporte'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () =>
                        Printing.sharePdf(bytes: pdfBytes, filename: fileName),
                    tooltip: 'Compartir PDF',
                  ),
                ],
              ),
              body: PdfPreview(
                build: (format) => Future.value(pdfBytes),
                allowSharing: true,
                allowPrinting: true,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: fileName,
              ),
            ),
          ),
        )
        .then((_) {
          // Cuando regrese de la vista previa, restaurar el estado de la lista de ventas
          final currentState = context.read<ReportsBloc>().state;
          if (currentState is ReportPdfGenerated) {
            // Recargar los datos
            _loadReports();
          }
        });
  }
}
