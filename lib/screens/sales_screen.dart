import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../services/receipt_service.dart';
import 'live_ocr_scanner_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<CartItem> _cart = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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

  double get _total =>
      _cart.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  void _onBarCodeDetected(String barcode) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final product = await context.read<ProductProvider>().findByBarcode(
      barcode,
    );

    if (product != null) {
      _addToCart(product);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} adicionado'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produto não encontrado')));
      }
    }

    // Short cooldown
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => const ProductSearchDialog(),
    ).then((product) {
      if (product != null && product is Product) {
        _addToCart(product);
      }
    });
  }

  void _onNameDetected(String name) async {
    // Similar to AddProductScreen but finds existing product
    final products = context.read<ProductProvider>().products;
    // Simple heuristic: find if any name contains the detected text
    final match = products.firstWhere(
      (p) => p.name.toLowerCase().contains(name.toLowerCase()),
      orElse: () => products.firstWhere(
        (p) => name.toLowerCase().contains(p.name.toLowerCase()),
        orElse: () => Product(
          name: 'Not Found',
          category: '',
          price: 0,
          stockQuantity: 0,
        ),
      ),
    );

    if (match.name != 'Not Found') {
      _addToCart(match);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reconhecido: ${match.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto não identificado pelo nome')),
      );
    }
  }

  void _showScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeScannerModal(
        onCodeDetected: (code) {
          _onBarCodeDetected(code);
        },
        onOcrRequested: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LiveOcrScannerScreen(),
            ),
          );
          if (result != null && result is String) {
            _onNameDetected(result);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venda Direta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'Buscar produto por nome',
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
                        title: Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'R\$ ${item.product.price.toStringAsFixed(2)} por unidade',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _updateQuantity(index, -1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () => _updateQuantity(index, 1),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'R\$ ${(item.product.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      onPressed: _cart.isEmpty
                          ? null
                          : () async {
                              final sale = Sale(
                                totalAmount: _total,
                                timestamp: DateTime.now(),
                                items: _cart
                                    .map(
                                      (item) => SaleItem(
                                        productId: item.product.id!,
                                        productName: item.product.name,
                                        quantity: item.quantity,
                                        priceAtSale: item.product.price,
                                      ),
                                    )
                                    .toList(),
                              );

                              try {
                                final saleId = await context
                                    .read<SalesProvider>()
                                    .addSale(sale);
                                final completeSale = Sale(
                                  id: saleId,
                                  totalAmount: sale.totalAmount,
                                  timestamp: sale.timestamp,
                                  items: sale.items,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Venda finalizada com sucesso!',
                                      ),
                                    ),
                                  );

                                  // Ask to print receipt
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Venda Concluída'),
                                      content: const Text(
                                        'Deseja imprimir o comprovante?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('NÃO'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await ReceiptService.printReceipt(
                                              completeSale,
                                            );
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
                                    SnackBar(
                                      content: Text(
                                        'Erro ao finalizar venda: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text('FINALIZAR VENDA'),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -80,
                right: 24,
                child: FloatingActionButton(
                  onPressed: _showScanner,
                  child: const Icon(Icons.qr_code_scanner, size: 28),
                ),
              ),
            ],
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

class BarcodeScannerModal extends StatefulWidget {
  final Function(String) onCodeDetected;
  final Function() onOcrRequested;
  const BarcodeScannerModal({
    super.key,
    required this.onCodeDetected,
    required this.onOcrRequested,
  });

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.stop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode != null) {
                  widget.onCodeDetected(barcode);
                }
              },
            ),
          ),
          // HUD Overlays
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                setState(() => _isFlashOn = !_isFlashOn);
                controller.toggleTorch();
              },
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Alinhe o código de barras',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                ),
              ),
            ),
          ),
          // OCR Fallback Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOcrRequested();
                },
                icon: const Icon(Icons.text_fields),
                label: const Text('LER NOME (OCR)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductSearchDialog extends StatefulWidget {
  const ProductSearchDialog({super.key});

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    // Start with all products
    _filteredProducts = context.read<ProductProvider>().products;
  }

  void _filterProducts(String query) {
    final allProducts = context.read<ProductProvider>().products;
    setState(() {
      _filteredProducts = allProducts
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por nome',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterProducts,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('Nenhum produto encontrado'))
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            'R\$ ${product.price.toStringAsFixed(2)}',
                          ),
                          trailing: Text('Stock: ${product.stockQuantity}'),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
