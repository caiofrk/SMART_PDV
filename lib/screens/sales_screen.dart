import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../services/receipt_service.dart';


class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<CartItem> _cart = [];
  bool _isScanning = false;

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index != -1) {
        _cart[index].quantity++;
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  void _onBarCodeDetected(BarcodeCapture capture) async {
    if (_isScanning) return;
    
    final barcode = capture.barcodes.first.rawValue;
    if (barcode != null) {
      setState(() => _isScanning = true);
      
      final product = await context.read<ProductProvider>().findByBarcode(barcode);
      
      if (product != null) {
        _addToCart(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} adicionado'), duration: const Duration(seconds: 1)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto não encontrado')),
        );
      }

      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venda Direta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: MobileScanner(onDetect: _onBarCodeDetected),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Carrinho vazio'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('R\$ ${item.product.price} x ${item.quantity}'),
                        trailing: Text(
                          'R\$ ${(item.product.price * item.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'R\$ ${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cart.isEmpty ? null : () async {
                    final sale = Sale(
                      totalAmount: _total,
                      timestamp: DateTime.now(),
                      items: _cart.map((item) => SaleItem(
                        productId: item.product.id!,
                        productName: item.product.name,
                        quantity: item.quantity,
                        priceAtSale: item.product.price,
                      )).toList(),
                    );

                    try {
                      final saleId = await context.read<SalesProvider>().addSale(sale);
                      final completeSale = Sale(
                        id: saleId,
                        totalAmount: sale.totalAmount,
                        timestamp: sale.timestamp,
                        items: sale.items,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Venda finalizada com sucesso!')),
                        );
                        
                        // Ask to print receipt
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Venda Concluída'),
                            content: const Text('Deseja imprimir o comprovante?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('NÃO'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await ReceiptService.printReceipt(completeSale);
                                },
                                child: const Text('SIM'),
                              ),
                            ],
                          ),
                        ).then((_) {
                          setState(() => _cart.clear());
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao finalizar venda: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: const Text('FINALIZAR VENDA'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, required this.quantity});
}
