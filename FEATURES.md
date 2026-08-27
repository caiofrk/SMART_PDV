# SMART_PDV (JL Tabacaria) - Current Features & Functionalities

This document outlines the core features and functionalities currently implemented in the SMART_PDV application.

## 1. Authentication & Security
- **Secure Login (`login_screen.dart`)**: User authentication gateway.
- **Backend Auth (`auth_provider.dart`, Supabase)**: Manages user sessions and integrates with Supabase for secure cloud authentication.

## 2. Point of Sale (POS) & Checkout
- **Sales Interface (`sales_screen.dart`)**: The primary checkout screen where cashiers can add products to a cart, adjust quantities, and process transactions.
- **Cart Management (`sales_provider.dart`)**: Handles the business logic for calculating totals, managing the active cart, and finalizing the sale.
- **Receipt Generation (`receipt_service.dart`)**: Automatically generates formatted transaction receipts (likely PDF) that can be printed or shared with the customer.

## 3. Inventory & Product Management
- **Inventory Overview (`inventory_screen.dart`)**: A dashboard to view all current stock, search for specific items, and monitor stock levels.
- **Product Entry (`add_product_screen.dart`)**: A detailed form to register new products or update existing details (price, stock, barcode, etc.).
- **Category Management (`category_management_screen.dart`)**: Allows the business to group products into logical categories for better organization and reporting.
- **State Management (`product_provider.dart`)**: Keeps the inventory UI synchronized with the underlying database.

## 4. Advanced Scanning (Camera Integration)
- **Barcode Scanning**: Built into the product and sales screens to quickly identify items without manual typing.
- **Live OCR Scanner (`live_ocr_scanner_screen.dart`, `ocr_service.dart`)**: Optical Character Recognition to extract text directly from the camera feed (e.g., quickly scanning product names or invoice details).

## 5. Reporting & Business Intelligence
- **Sales Reports (`reports_screen.dart`)**: Provides visualizations and summaries of sales data, revenue tracking, and business performance metrics over time.

## 6. Data Storage, Cloud & Backups
- **Local Database (`database_helper.dart`)**: Uses SQLite for fast, robust local data storage, allowing the app to function efficiently.
- **Cloud Backend (`supabase_config.dart`)**: Connected to Supabase for cloud infrastructure.
- **Database Backups (`backup_service.dart`)**: Features an export tool that packages the local database file and allows the user to share/save it externally using the native share sheet.
