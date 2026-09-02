import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared/shared.dart';
import '../models/sale.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_system.db');
    return _database!;
  }

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'pos_system.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      // Migrating current categories if any or just adding defaults
      final initialCategories = [
        'Narguile',
        'Essências',
        'Carvão',
        'Isqueiros',
        'Charutos',
        'Juices',
        'Vapes',
        'Acessórios',
        'Outros',
      ];
      for (var cat in initialCategories) {
        await db.insert('categories', {'name': cat});
      }
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE products ADD COLUMN last_updated TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN sync_status TEXT DEFAULT "pending"');
      await db.execute('ALTER TABLE sales ADD COLUMN sync_status TEXT DEFAULT "pending"');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        stockQuantity INTEGER NOT NULL,
        imagePath TEXT,
        category TEXT,
        last_updated TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    final initialCategories = [
      'Narguile',
      'Essências',
      'Carvão',
      'Isqueiros',
      'Charutos',
      'Juices',
      'Vapes',
      'Acessórios',
      'Outros',
    ];
    for (var cat in initialCategories) {
      await db.insert('categories', {'name': cat});
    }

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        totalAmount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        priceAtSale REAL NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales (id),
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // Create a default admin user
    await db.insert('users', {
      'username': 'admin',
      'password': hashPassword('admin'),
      'role': 'admin',
    });
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Product methods
  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    final map = product.toMap();
    map['last_updated'] = DateTime.now().toIso8601String();
    map['sync_status'] = 'pending';
    return await db.insert('products', map);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await instance.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    final map = product.toMap();
    map['last_updated'] = DateTime.now().toIso8601String();
    map['sync_status'] = 'pending';
    return await db.update(
      'products',
      map,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Sales methods
  Future<int> createSale(Sale sale) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Insert Sale with pending sync status
      final saleMap = sale.toMap();
      saleMap['sync_status'] = 'pending';
      final saleId = await txn.insert('sales', saleMap);

      // 2. Insert Sale Items and update stock
      for (var item in sale.items) {
        await txn.insert('sale_items', item.toMap(saleId));

        // Update product stock and mark as pending sync for cloud reflection
        await txn.execute(
          'UPDATE products SET stockQuantity = stockQuantity - ?, last_updated = ?, sync_status = "pending" WHERE id = ?',
          [item.quantity, DateTime.now().toIso8601String(), item.productId],
        );
      }
      return saleId;
    });
  }

  // Sync pipeline queries
  Future<List<Map<String, dynamic>>> getPendingProducts() async {
    final db = await instance.database;
    return await db.query(
      'products',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
  }

  Future<void> markProductsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.execute(
      'UPDATE products SET sync_status = "synced" WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final db = await instance.database;
    final salesResult = await db.query(
      'sales',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );

    List<Map<String, dynamic>> fullSales = [];
    for (var sale in salesResult) {
      final saleId = sale['id'] as int;
      final items = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      fullSales.add({
        'sale': sale,
        'items': items,
      });
    }
    return fullSales;
  }

  Future<void> markSalesSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.execute(
      'UPDATE sales SET sync_status = "synced" WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await instance.database;
    final pendingProducts = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products WHERE sync_status = "pending"'),
    ) ?? 0;
    final pendingSales = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sales WHERE sync_status = "pending"'),
    ) ?? 0;
    return pendingProducts + pendingSales;
  }

  Future<List<Sale>> getSalesHistory() async {
    final db = await instance.database;
    final result = await db.query('sales', orderBy: 'timestamp DESC');

    List<Sale> sales = [];
    for (var row in result) {
      final saleId = row['id'] as int;
      final itemsResult = await db.rawQuery(
        '''
        SELECT si.*, p.name as productName 
        FROM sale_items si
        JOIN products p ON si.productId = p.id
        WHERE si.saleId = ?
      ''',
        [saleId],
      );

      final items = itemsResult.map((i) => SaleItem.fromMap(i)).toList();
      sales.add(Sale.fromMap(row, items: items));
    }
    return sales;
  }

  // User methods
  Future<User?> login(String username, String password) async {
    final db = await instance.database;
    final hashedPassword = hashPassword(password);

    final maps = await db.query(
      'users',
      where: 'username = ? AND (password = ? OR password = ?)',
      whereArgs: [
        username,
        hashedPassword,
        password,
      ], // Legacy support for plain text admin until re-registered
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> registerUser(User user) async {
    final db = await instance.database;
    final newUser = User(
      username: user.username,
      password: hashPassword(user.password),
      role: user.role,
    );
    return await db.insert('users', newUser.toMap());
  }

  Future<int> updateUserPassword(int userId, String newPassword) async {
    final db = await instance.database;
    final hashedPassword = hashPassword(newPassword);
    return await db.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Category methods
  Future<List<String>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((json) => json['name'] as String).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await instance.database;
    return await db.insert('categories', {'name': name});
  }

  Future<int> deleteCategory(String name) async {
    final db = await instance.database;
    // 1. Move products in this category to 'Outros'
    await db.update(
      'products',
      {'category': 'Outros'},
      where: 'category = ?',
      whereArgs: [name],
    );
    // 2. Delete the category
    return await db.delete('categories', where: 'name = ?', whereArgs: [name]);
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Update categories table
      await txn.update(
        'categories',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      // 2. Update products table
      await txn.update(
        'products',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
