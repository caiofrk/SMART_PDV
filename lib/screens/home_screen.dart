import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'inventory_screen.dart';
import 'add_product_screen.dart';
import 'sales_screen.dart';
import 'reports_screen.dart';
import 'change_password_screen.dart';
import '../widgets/low_stock_alert.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
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
    Future.microtask(
      () => context.read<ProductProvider>().fetchAndSetProducts(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'JL TABACARIA',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      drawer: Consumer<AuthProvider>(
        builder: (context, auth, _) => Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                accountName: Text(
                  auth.currentUser?.username.toUpperCase() ?? 'CONVIDADO',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: Text(
                  auth.currentUser?.role == 'admin'
                      ? 'Administrador'
                      : 'Funcionário',
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Alterar Senha'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
              if (auth.currentUser?.role == 'admin')
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Exportar Backup (Drive/Local)'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    BackupService.exportDatabase(context);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  auth.logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface,
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
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (!auth.isUsingDefaultPassword)
                    return const SizedBox.shrink();
                  return Card(
                    color: Colors.orange.shade900.withOpacity(0.2),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      title: const Text(
                        'Senha Padrão Detectada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Por segurança, altere sua senha agora.',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        ),
                        child: const Text('ALTERAR'),
                      ),
                    ),
                  );
                },
              ),
              const LowStockAlert(),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final isAdmin = auth.currentUser?.role == 'admin';
                  return Expanded(
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
                              MaterialPageRoute(
                                builder: (_) => const SalesScreen(),
                              ),
                            );
                          },
                        ),
                        if (isAdmin)
                          _buildMenuCard(
                            context,
                            'Estoque',
                            Icons.inventory_2,
                            Colors.brown.shade600,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InventoryScreen(),
                                ),
                              );
                            },
                          ),
                        if (isAdmin)
                          _buildMenuCard(
                            context,
                            'Adicionar Item',
                            Icons.qr_code_scanner,
                            Colors.teal.shade600,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddProductScreen(),
                                ),
                              );
                            },
                          ),
                        if (isAdmin)
                          _buildMenuCard(
                            context,
                            'Relatórios',
                            Icons.bar_chart,
                            Colors.blueGrey.shade600,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportsScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
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
        CircleAvatar(
          radius: 40,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.2),
          child: Icon(
            Icons.store,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bem-vindo ao PDV',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          'Gerencie sua tabacaria com facilidade',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            border: Border(bottom: BorderSide(color: color, width: 4)),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
