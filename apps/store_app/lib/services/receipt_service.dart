import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';

class ReceiptService {
  static Future<void> printReceipt(Sale sale) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard thermal printer width
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('JL TABACARIA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ),
              pw.Center(child: pw.Text('Comprovante de Venda')),
              pw.Divider(),
              pw.Text('Data: ${dateFormat.format(sale.timestamp)}'),
              pw.Text('Venda ID: #${sale.id ?? "N/A"}'),
              pw.Divider(),
              pw.Table(
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Prod', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qtde', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Preço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...sale.items.map((item) => pw.TableRow(
                        children: [
                          pw.Text(item.productName),
                          pw.Text(item.quantity.toString()),
                          pw.Text('R\$ ${item.priceAtSale.toStringAsFixed(2)}'),
                        ],
                      )),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('R\$ ${sale.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Obrigado pela preferência!')),
              pw.Center(child: pw.Text('JL Tabacaria - Qualidade e Confiança')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}
