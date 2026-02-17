import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import 'dart:io';
import '../services/ocr_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? _selectedCategory;

  File? _image;
  final _picker = ImagePicker();

  bool _isOcrLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    OcrService.dispose();
    super.dispose();
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

  void _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (barcode != null) {
      setState(() {
        _barcodeController.text = barcode;
      });
    }
  }

  void _scanName() async {
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const TextScannerScreen()),
    );

    if (name != null) {
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
      final product = Product(
        name: _nameController.text,
        barcode: _barcodeController.text.isEmpty
            ? null
            : _barcodeController.text,
        price:
            double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0,
        stockQuantity: int.tryParse(_stockController.text) ?? 0,
        imagePath: _image?.path,
        category: _selectedCategory,
      );

      await context.read<ProductProvider>().addProduct(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto adicionado com sucesso!')),
        );
        Navigator.pop(context);
      }
    }
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
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                child: InkWell(
                  onTap: _scanBarcode,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CLIQUE PARA ESCANEAR BARCODE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
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
                    value: _selectedCategory,
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
                      validator: (value) =>
                          value!.isEmpty ? 'Obrigatório' : null,
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
                label: const Text('SALVAR PRODUTO'),
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
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
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

class TextScannerScreen extends StatefulWidget {
  const TextScannerScreen({super.key});

  @override
  State<TextScannerScreen> createState() => _TextScannerScreenState();
}

class _TextScannerScreenState extends State<TextScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Nome')),
      body: Stack(
        children: [
          // Using a simple camera preview for OCR capture
          // In a real environment, we'd use a camera package, but here we reuse ImagePicker for reliability
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.text_fields, size: 64, color: Colors.blue),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Toque no botão abaixo para tirar uma foto nítida do nome do produto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null && mounted) {
                      final text = await OcrService.extractProductName(
                        File(photo.path),
                      );
                      Navigator.pop(context, text);
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('CAPTURAR E ANALISAR'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
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
