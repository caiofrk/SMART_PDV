import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'inventory_screen.dart';
import 'add_product_screen.dart';
import 'sales_screen.dart';
import 'reports_screen.dart';
import '../widgets/low_stock_alert.dart';
import '../providers/product_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load products on home to check for low stock alerts
    Future.microtask(() => 
      context.read<ProductProvider>().fetchAndSetProducts()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'JL TABACARIA',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              const LowStockAlert(),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      'Venda Direta',
                      Icons.shopping_cart_checkout,
                      Colors.amber.shade700,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SalesScreen()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Estoque',
                      Icons.inventory_2,
                      Colors.brown.shade600,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InventoryScreen()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Adicionar Item',
                      Icons.add_a_photo,
                      Colors.teal.shade600,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddProductScreen()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Relatórios',
                      Icons.bar_chart,
                      Colors.blueGrey.shade600,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFF6D4C41),
          child: Icon(Icons.store, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Bem-vindo ao PDV',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.brown.shade900,
          ),
        ),
        Text(
          'Gerencie sua tabacaria com facilidade',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Colors.brown.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: 4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
