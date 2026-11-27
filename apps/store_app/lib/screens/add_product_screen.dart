import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../providers/product_provider.dart';
import 'dart:io';
import '../services/ocr_service.dart';
import 'live_ocr_scanner_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  // New controllers for cost breakdown
  final _costController = TextEditingController();
  final _expensesController = TextEditingController();
  final _taxesController = TextEditingController();
  final _marginController = TextEditingController();
  String? _selectedCategory;
  int? _existingProductId;

  File? _image;
  final _picker = ImagePicker();

  bool _isOcrLoading = false;
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    OcrService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _scannerController.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _scannerController.stop();
        break;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      setState(() {
        _image = imageFile;
      });

      // Automatically try to extract name if field is empty
      if (_nameController.text.isEmpty) {
        _performOcr(imageFile);
      }
    }
  }

  void _performOcr(File image) async {
    setState(() => _isOcrLoading = true);

    final detectedName = await OcrService.extractProductName(image);

    if (detectedName != null && mounted) {
      setState(() {
        _nameController.text = detectedName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do produto detectado via OCR!')),
      );
    }

    setState(() => _isOcrLoading = false);
  }

  void _handleDetectedBarcode(String barcode) async {
    if (barcode == _barcodeController.text) return; // Ignore if same

    setState(() {
      _barcodeController.text = barcode;
    });

    // Local lookup - checking if we already know this "sibling"
    final existingProduct = await context.read<ProductProvider>().findByBarcode(
      barcode,
    );

    if (existingProduct != null && mounted) {
      setState(() {
        _existingProductId = existingProduct.id;
        if (_nameController.text.isEmpty) {
          _nameController.text = existingProduct.name;
        }
        _selectedCategory = existingProduct.category;
        if (existingProduct.price > 0) {
          _priceController.text = NumberFormat.simpleCurrency(
            locale: "pt_BR",
          ).format(existingProduct.price);
        }
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produto "${existingProduct.name}" reconhecido. Altere os dados e salve para atualizar.'),
          backgroundColor: Colors.indigo,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (barcode != null) {
      _handleDetectedBarcode(barcode);
    }
  }

  void _scanName() async {
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const LiveOcrScannerScreen()),
    );

    if (name != null) {
      if (!mounted) return;
      setState(() {
        _nameController.text = name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome capturado com sucesso!')),
      );
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
      final parsedPrice = _parsePrice(_priceController.text);
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;
      final provider = context.read<ProductProvider>();

      // Check if product already exists by tracked ID or by barcode
      int? targetId = _existingProductId;
      if (targetId == null && barcode != null) {
        final existingByBarcode = await provider.findByBarcode(barcode);
        if (existingByBarcode != null) {
          targetId = existingByBarcode.id;
        }
      }

      if (targetId != null) {
        final updatedProduct = Product(
          id: targetId,
          name: _nameController.text.trim(),
          barcode: barcode,
          price: parsedPrice,
          stockQuantity: stock,
          imagePath: _image?.path,
          category: _selectedCategory,
        );
        await provider.updateProduct(updatedProduct);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto atualizado com sucesso!')),
          );
          Navigator.pop(context);
        }
      } else {
        final product = Product(
          name: _nameController.text.trim(),
          barcode: barcode,
          price: parsedPrice,
          stockQuantity: stock,
          imagePath: _image?.path,
          category: _selectedCategory,
        );
        await provider.addProduct(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto adicionado com sucesso!')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  double _parsePrice(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('\u00a0', '').trim();
    if (cleaned.isEmpty) return 0.0;

    if (cleaned.contains('.') && cleaned.contains(',')) {
      if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }

    final directParsed = double.tryParse(cleaned);
    if (directParsed != null && directParsed > 0) {
      return directParsed;
    }

    // Fallback: digits only / 100
    String digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return 0.0;
    return (double.tryParse(digitsOnly) ?? 0.0) / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Produto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Quick Scan at the top
              // 1. Live Scanner Frame
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final barcode = capture.barcodes.first.rawValue;
                          if (barcode != null) {
                            _handleDetectedBarcode(barcode);
                          }
                        },
                      ),
                      // Scanner Overlay Frame
                      Center(
                        child: Container(
                          width: 200,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.cyanAccent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Flash Toggle
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: const Icon(
                              Icons.flash_on,
                              color: Colors.white,
                            ),
                            onPressed: () => _scannerController.toggleTorch(),
                          ),
                        ),
                      ),
                      // Label
                      Positioned(
                        bottom: 15,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ALINHE O CÓDIGO AQUI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome do Produto',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: _isOcrLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_image != null)
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _performOcr(_image!),
                                tooltip: 'Re-extrair da foto',
                              ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt),
                              onPressed: _scanName,
                              tooltip: 'Escanear nome com a câmera',
                            ),
                          ],
                        ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Consumer<ProductProvider>(
                builder: (context, provider, _) {
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: provider.categories
                        .where((cat) => cat != 'Todos')
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    validator: (value) =>
                        value == null ? 'Selecione uma categoria' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de Barras',
                        prefixIcon: Icon(Icons.qr_code_scanner),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.camera_alt),
                    tooltip: 'Escanear',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Preço (R\$)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        if (_parsePrice(value) <= 0) {
                          return 'Informe um preço válido maior que zero';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estoque Inicial',
                        prefixIcon: Icon(Icons.inventory),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Foto do Produto (Opcional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImageSelector(),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveProduct,
                icon: const Icon(Icons.save),
                label: Text(
                  _existingProductId != null
                      ? 'ATUALIZAR PRODUTO'
                      : 'SALVAR PRODUTO',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: _image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tirar foto do produto',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              controller.stop();
              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip everything except digits
    String cleaned = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return newValue.copyWith(text: '');

    double value = double.parse(cleaned);
    final formatter = NumberFormat.simpleCurrency(locale: "pt_BR");
    String newText = formatter.format(value / 100);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
