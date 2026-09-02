import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class SalesProvider with ChangeNotifier {
  List<Sale> _salesHistory = [];
  bool _isLoading = false;

  List<Sale> get salesHistory => [..._salesHistory];
  bool get isLoading => _isLoading;

  Future<void> fetchSalesHistory() async {
    _isLoading = true;
    notifyListeners();
    _salesHistory = await DatabaseHelper.instance.getSalesHistory();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> addSale(Sale sale) async {
    final id = await DatabaseHelper.instance.createSale(sale);
    await fetchSalesHistory(); // Refresh history
    SyncService.instance.updatePendingCount();
    return id;
  }
}
