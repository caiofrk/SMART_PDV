import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  Timer? _periodicTimer;
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  SyncService._init();

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    updatePendingCount();
    _periodicTimer = Timer.periodic(interval, (_) => syncDelta());
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> updatePendingCount() async {
    try {
      final count = await DatabaseHelper.instance.getPendingSyncCount();
      pendingCount.value = count;
    } catch (_) {}
  }

  Future<bool> syncDelta() async {
    if (isSyncing.value) return false;

    final client = Supabase.instance.client;
    // Only attempt sync if a session is present or anonymous calls are allowed
    isSyncing.value = true;

    try {
      // 1. Sync Pending Products
      final pendingProducts = await DatabaseHelper.instance.getPendingProducts();
      if (pendingProducts.isNotEmpty) {
        final List<int> syncedProductIds = [];

        for (final row in pendingProducts) {
          try {
            final Map<String, dynamic> supabaseData = {
              'name': row['name'],
              'barcode': row['barcode'],
              'price': row['price'],
              'stock_quantity': row['stockQuantity'],
              'image_path': row['imagePath'],
              'category': row['category'],
              'last_updated': row['last_updated'] ?? DateTime.now().toIso8601String(),
            };

            // If barcode is present, check/upsert by barcode or insert
            final barcode = row['barcode']?.toString();
            if (barcode != null && barcode.isNotEmpty) {
              final existing = await client
                  .from('products')
                  .select('id')
                  .eq('barcode', barcode)
                  .maybeSingle();

              if (existing != null) {
                await client
                    .from('products')
                    .update(supabaseData)
                    .eq('id', existing['id']);
              } else {
                await client.from('products').insert(supabaseData);
              }
            } else {
              await client.from('products').insert(supabaseData);
            }

            syncedProductIds.add(row['id'] as int);
          } catch (itemErr) {
            debugPrint('Error syncing product ${row['id']}: $itemErr');
          }
        }

        if (syncedProductIds.isNotEmpty) {
          await DatabaseHelper.instance.markProductsSynced(syncedProductIds);
        }
      }

      // 2. Sync Pending Sales
      final pendingSales = await DatabaseHelper.instance.getPendingSales();
      if (pendingSales.isNotEmpty) {
        final List<int> syncedSaleIds = [];

        for (final item in pendingSales) {
          try {
            final saleRow = item['sale'] as Map<String, dynamic>;
            final itemsRows = item['items'] as List<Map<String, dynamic>>;

            final insertedSale = await client.from('sales').insert({
              'total_amount': saleRow['totalAmount'],
              'timestamp': saleRow['timestamp'],
            }).select('id').single();

            final remoteSaleId = insertedSale['id'];

            if (itemsRows.isNotEmpty) {
              final remoteItems = itemsRows.map((si) => {
                'sale_id': remoteSaleId,
                'product_id': null, // Local SQLite product IDs are decoupled
                'product_name': si['productName'] ?? 'Item',
                'quantity': si['quantity'],
                'price_at_sale': si['priceAtSale'],
              }).toList();

              await client.from('sale_items').insert(remoteItems);
            }

            syncedSaleIds.add(saleRow['id'] as int);
          } catch (saleErr) {
            debugPrint('Error syncing sale: $saleErr');
          }
        }

        if (syncedSaleIds.isNotEmpty) {
          await DatabaseHelper.instance.markSalesSynced(syncedSaleIds);
        }
      }

      await updatePendingCount();
      return true;
    } catch (e) {
      debugPrint('Sync failed (will retry next interval): $e');
      return false;
    } finally {
      isSyncing.value = false;
      await updatePendingCount();
    }
  }
}
