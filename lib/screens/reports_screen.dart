import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../models/sale.dart';
import '../services/receipt_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<SalesProvider>().fetchSalesHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Vendas'),
      ),
      body: Consumer<SalesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.salesHistory.isEmpty) {
            return const Center(child: Text('Nenhuma venda registrada.'));
          }

          final totalRevenue = provider.salesHistory.fold(0.0, (sum, sale) => sum + sale.totalAmount);

          return Column(
            children: [
              _buildSummaryCard(totalRevenue, provider.salesHistory.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.salesHistory.length,
                  itemBuilder: (context, index) {
                    final sale = provider.salesHistory[index];
                    return _buildSaleCard(sale);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Faturamento Total',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            'R$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count vendas realizadas',
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text('Venda #${sale.id}'),
        subtitle: Text(dateFormat.format(sale.timestamp)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R$ ${sale.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.productName}'),
                          Text('R$ ${(item.priceAtSale * item.quantity).toStringAsFixed(2)}'),
                        ],
                      ),
                    )),
                const Divider(),
                ElevatedButton.icon(
                  onPressed: () => ReceiptService.printReceipt(sale),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('REIMPRIMIR COMPROVANTE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
