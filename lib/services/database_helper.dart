import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';

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
      version: 1,
      onCreate: _createDB,
    );
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
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        totalAmount REAL NOT NULL,
        timestamp TEXT NOT NULL
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
      'password': 'admin', // In production, hash this!
      'role': 'admin'
    });
  }

  // Product methods
  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
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
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sales methods
  Future<int> createSale(Sale sale) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Insert Sale
      final saleId = await txn.insert('sales', sale.toMap());

      // 2. Insert Sale Items and update stock
      for (var item in sale.items) {
        await txn.insert('sale_items', item.toMap(saleId));
        
        // Update product stock
        await txn.execute(
          'UPDATE products SET stockQuantity = stockQuantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return saleId;
    });
  }

  Future<List<Sale>> getSalesHistory() async {
    final db = await instance.database;
    final result = await db.query('sales', orderBy: 'timestamp DESC');
    
    List<Sale> sales = [];
    for (var row in result) {
      final saleId = row['id'] as int;
      final itemsResult = await db.rawQuery('''
        SELECT si.*, p.name as productName 
        FROM sale_items si
        JOIN products p ON si.productId = p.id
        WHERE si.saleId = ?
      ''', [saleId]);
      
      final items = itemsResult.map((i) => SaleItem.fromMap(i)).toList();
      sales.add(Sale.fromMap(row, items: items));
    }
    return sales;
  }

  // User methods
  Future<User?> login(String username, String password) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> registerUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
