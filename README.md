# POS Inventory Management App

A simple, offline, tablet-optimized Point of Sale (POS) and Inventory Management application built with Flutter.

## Features

- **Product Management**: Add, edit, and manage products with barcode support
- **Point of Sale**: Scan barcodes and process sales transactions
- **Inventory Tracking**: Automatic stock deduction on sales
- **Sales Reports**: View daily sales and product reports
- **100% Offline**: All data stored locally using SQLite
- **Tablet Optimized**: Designed for Android tablets in landscape mode

## Requirements

- Flutter SDK (latest stable)
- Android SDK (API 21+)
- Android tablet device or emulator

## Setup Instructions

1. **Install Dependencies**
   ```bash
   cd pos_inventory_app
   flutter pub get
   ```

2. **Run the App**
   ```bash
   flutter run
   ```

## App Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── product.dart            # Product model
├── helpers/
│   └── database_helper.dart     # SQLite database operations
└── screens/
    ├── home_screen.dart         # Main navigation screen
    ├── product_management_screen.dart  # Product CRUD
    ├── pos_screen.dart          # Point of Sale with barcode scanning
    └── reports_screen.dart      # Sales reports
```

## Database Schema

### Products Table
- `id` (INTEGER PRIMARY KEY)
- `name` (TEXT)
- `barcode` (TEXT, nullable)
- `price` (REAL)
- `quantity` (INTEGER)

### Sales Table
- `id` (INTEGER PRIMARY KEY)
- `total` (REAL)
- `date` (TEXT)

### Sale Items Table
- `id` (INTEGER PRIMARY KEY)
- `sale_id` (INTEGER, FOREIGN KEY)
- `product_id` (INTEGER, FOREIGN KEY)
- `quantity` (INTEGER)
- `price` (REAL)

## Usage

1. **Add Products**: Go to Products screen and add products with name, price, and optional barcode
2. **Process Sales**: Go to POS screen, scan barcodes or manually add items to cart, then checkout
3. **View Reports**: Go to Reports screen to see daily sales and products sold

## Notes

- The app is configured to run in landscape mode for tablets
- Camera permission is required for barcode scanning
- All data is stored locally on the device



