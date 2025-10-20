import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/database.dart';

class PdfReportService {
  static final _dateFormatter = DateFormat('dd/MM/yyyy');
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'es_ES',
    symbol: 'Bs.',
    decimalDigits: 2,
  );

  Future<Uint8List> generateSalesReport({
    required List<Sale> sales,
    required String userName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Calculate totals
    final totalAmount = sales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final totalSales = sales.length;

    // Determine date range text
    String dateRangeText;
    if (startDate != null && endDate != null) {
      dateRangeText =
          'Del ${_dateFormatter.format(startDate)} al ${_dateFormatter.format(endDate)}';
    } else {
      dateRangeText = 'Todas las ventas';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(userName, dateRangeText),
            pw.SizedBox(height: 20),

            // Summary
            _buildSummary(totalSales, totalAmount),
            pw.SizedBox(height: 20),

            // Sales table
            _buildSalesTable(sales),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildHeader(String userName, String dateRangeText) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REPORTE DE VENTAS',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Vendedor: $userName', style: pw.TextStyle(fontSize: 16)),
        pw.Text('Período: $dateRangeText', style: pw.TextStyle(fontSize: 16)),
        pw.Text(
          'Fecha de generación: ${_dateFormatter.format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildSummary(int totalSales, double totalAmount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'Total de Ventas',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                totalSales.toString(),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ],
          ),
          pw.Container(width: 1, height: 40, color: PdfColors.grey400),
          pw.Column(
            children: [
              pw.Text(
                'Monto Total',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _currencyFormatter.format(totalAmount),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSalesTable(List<Sale> sales) {
    if (sales.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text(
          'No se encontraron ventas en el período seleccionado.',
          style: pw.TextStyle(
            fontSize: 16,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Fecha
        1: const pw.FlexColumnWidth(3), // Cliente
        2: const pw.FlexColumnWidth(2), // Método de pago
        3: const pw.FlexColumnWidth(2), // Monto
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Fecha', isHeader: true),
            _buildTableCell('Cliente', isHeader: true),
            _buildTableCell('Método de Pago', isHeader: true),
            _buildTableCell('Monto', isHeader: true),
          ],
        ),
        // Data rows
        ...sales.map(
          (sale) => pw.TableRow(
            children: [
              _buildTableCell(_dateFormatter.format(sale.saleDate)),
              _buildTableCell(sale.customerName ?? 'Cliente general'),
              _buildTableCell(_getPaymentMethodName(sale.paymentMethod)),
              _buildTableCell(
                _currencyFormatter.format(sale.totalAmount),
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ),
        // Total row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell(''),
            _buildTableCell(''),
            _buildTableCell(
              'TOTAL:',
              isHeader: true,
              textAlign: pw.TextAlign.right,
            ),
            _buildTableCell(
              _currencyFormatter.format(
                sales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount),
              ),
              isHeader: true,
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: textAlign,
      ),
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

  /// Generate admin sales report PDF with data from all users
  Future<Uint8List> generateAdminSalesReport({
    required Map<String, List<Sale>> salesByUser,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Calculate overall totals
    final allSales = salesByUser.values.expand((sales) => sales).toList();
    final totalAmount = allSales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final totalSales = allSales.length;
    final totalUsers = salesByUser.length;

    // Determine date range text
    String dateRangeText;
    if (startDate != null && endDate != null) {
      dateRangeText =
          'Del ${_dateFormatter.format(startDate)} al ${_dateFormatter.format(endDate)}';
    } else {
      dateRangeText = 'Todas las ventas';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildAdminHeader(dateRangeText),
            pw.SizedBox(height: 20),

            // Summary
            _buildAdminSummary(totalSales, totalAmount, totalUsers),
            pw.SizedBox(height: 30),

            // Sales by user
            _buildSalesByUserSection(salesByUser),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildAdminHeader(String dateRangeText) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REPORTE ADMINISTRATIVO DE VENTAS',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Sistema de Almacenes',
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Período: $dateRangeText',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generado: ${_dateFormatter.format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildAdminSummary(int totalSales, double totalAmount, int totalUsers) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMEN GENERAL',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Usuarios Activos', '$totalUsers'),
              _buildSummaryItem('Total Ventas', '$totalSales'),
              _buildSummaryItem('Ingresos Totales', _currencyFormatter.format(totalAmount)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSalesByUserSection(Map<String, List<Sale>> salesByUser) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'VENTAS POR USUARIO',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 16),
        
        // User summary table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Usuario', isHeader: true),
                _buildTableCell('Ventas', isHeader: true, textAlign: pw.TextAlign.center),
                _buildTableCell('Total Vendido', isHeader: true, textAlign: pw.TextAlign.right),
              ],
            ),
            // Data rows
            ...salesByUser.entries.map((entry) {
              final userName = entry.key;
              final userSales = entry.value;
              final userTotal = userSales.fold<double>(
                0.0,
                (sum, sale) => sum + sale.totalAmount,
              );
              
              return pw.TableRow(
                children: [
                  _buildTableCell(userName),
                  _buildTableCell('${userSales.length}', textAlign: pw.TextAlign.center),
                  _buildTableCell(_currencyFormatter.format(userTotal), textAlign: pw.TextAlign.right),
                ],
              );
            }).toList(),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        // Detailed sales by user
        ...salesByUser.entries.map((entry) {
          final userName = entry.key;
          final userSales = entry.value;
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Text(
                'Ventas de $userName',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 8),
              
              // Sales table for this user
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('Venta #', isHeader: true),
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Método Pago', isHeader: true),
                      _buildTableCell('Total', isHeader: true, textAlign: pw.TextAlign.right),
                    ],
                  ),
                  // Sales data
                  ...userSales.map((sale) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(sale.id.toString()),
                        _buildTableCell(_dateFormatter.format(sale.saleDate)),
                        _buildTableCell(_getPaymentMethodName(sale.paymentMethod)),
                        _buildTableCell(_currencyFormatter.format(sale.totalAmount), textAlign: pw.TextAlign.right),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}
