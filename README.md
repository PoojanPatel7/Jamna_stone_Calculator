<p align="center">
  <img src="Logo.jpeg" alt="Jamna Stone Logo" width="150" height="150" style="border-radius: 20px;" />
</p>

<h1 align="center">Jamna Stone — Slab Calculator & Stock Manager</h1>

<p align="center">
  <em>The ultimate stone-industry companion for measuring, managing, backing up, and exporting granite & marble slab data — built for professionals who demand precision and reliability.</em>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://github.com/PoojanPatel7/Jamna_stone_Calculator/releases"><img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License" /></a>
  <a href="https://github.com/PoojanPatel7/Jamna_stone_Calculator/releases"><img src="https://img.shields.io/badge/Version-1.0.2-blue" alt="Version" /></a>
</p>

---

## 📖 Overview

**Jamna Stone** is a production-grade Flutter application purpose-built for **stone businesses, marble dealers, and granite traders**. It streamlines the entire workflow of measuring, cataloguing, stocking, and exporting granite and marble slab dimensions — replacing error-prone notebooks and spreadsheets with an intelligent, offline-first mobile tool.

Whether you're at the quarry, in the warehouse, or on-site with a client, Jamna Stone ensures your measurements are accurate, your stock is tracked, your data is backed up locally, and everything is beautifully exportable as professional PDF reports.

---

## 🆕 What's New in v1.0.2

### 🔄 Smart Local Backup & Restore System
- **Persistent Local Backups** — All data is backed up to `Documents/Jamna Stone Backup/` on your device's local storage, surviving even app uninstalls
- **Differential Backup** — Only new and modified records are synced, making backups lightning fast
- **Differential Restore** — Only missing data is imported from backups, preventing any duplicate entries
- **Sync Status Tracking** — Every measurement book and stock entry tracks its own `isSynced` status with visual indicators (✅ Synced / 🔄 Pending)
- **Live Process Animations** — Beautiful scanning, syncing, and success animations displayed in real-time during backup/restore operations
- **Smart Button States** — Buttons disable during processing to prevent duplicate operations, with live status text updates

### 📦 Full Stock Management Module
- **Complete Stock Tracking** — Add, edit, and delete stock entries with granite name, thickness, quantity, and pricing
- **Professional Stock PDFs** — Export stock reports as print-ready PDFs
- **Integrated with Backup** — All stock data is included in local backup/restore operations

### 🎨 Redesigned UI/UX
- **Glassmorphic Popups** — Frosted glass blur effect with smooth scale-in transitions for all dialogs
- **AnimatedSwitcher Transitions** — Smooth cross-fade between popup states (initial → scanning → syncing → success/error)
- **Premium Card Design** — Rounded corners (32px radius), elevated shadows, and gradient icon containers
- **Micro-Animations** — Bouncy success checkmarks, pulsating scan icons, rotating sync indicators

---

## ✨ Key Features

### 📏 Intelligent Slab Measurement
| Feature | Description |
|---|---|
| **Auto-Save** | Every keystroke is persisted instantly — zero data loss from crashes or closures |
| **Smart Fill-Down** | Automatically populates height/width gaps between entries for rapid bulk input |
| **Real-Time Calculations** | Live area computation in **Sq. Feet**, **Sq. Meters**, and **Sq. Inches** |
| **Undo / Redo** | Full action history to quickly revert or restore during fast data entry |
| **Mandatory Fields** | Enforces granite name, party name, and date to ensure data integrity |

### 📚 Measurement Books
- Create named "books" per granite lot, party, or truck load
- Each book stores unlimited slabs with length × width dimensions
- Switch between **Card View** and **Table View** for different workflows
- Full CRUD — edit, duplicate, or delete any book or slab entry
- **Sync status badge** on each book showing backup state

### 📦 Stock Management
| Feature | Description |
|---|---|
| **Stock Entries** | Track granite stock with name, thickness, quantity, and rate |
| **Search & Filter** | Quickly find stock items across your entire inventory |
| **Stock Reports** | Export professional PDF reports for inventory audits |
| **Sync Tracking** | Visual sync indicators showing which entries are backed up |

### 🔄 Backup & Restore System
| Feature | Description |
|---|---|
| **Local Storage Backup** | Data saved to `Documents/Jamna Stone Backup/` — persists through app uninstalls |
| **Differential Sync** | Only new/modified records are backed up or restored — no duplicates, ever |
| **Scanning Animation** | Animated magnifying glass icon during the pre-flight data comparison phase |
| **Syncing Animation** | Rotating cloud-sync icon with progress bar during actual data transfer |
| **Success Animation** | Bouncy green checkmark with elastic scale effect on completion |
| **Error Handling** | Shaking red error icon with clear failure messaging |
| **Auto-Close** | Popup automatically closes after success and refreshes the underlying page |
| **Button Lock** | Confirm button disables during processing to prevent accidental double-taps |

### 🔒 Security & Privacy
- **4-Digit PIN Lock** — Protect sensitive business data behind a personal PIN
- **Secure Recovery** — Built-in developer recovery PIN (`9009`) prevents permanent lockouts
- **100% Offline** — All data is stored locally on-device; nothing ever leaves your phone
- **Clean PDF Exports** — Developer credentials are excluded from shared documents
- **Persistent Data** — Backup folder survives app uninstall (`hasFragileUserData` enabled)

### 📄 Professional PDF Reporting
- Export any measurement book as a **high-quality, print-ready PDF**
- Export stock inventory as structured PDF reports
- Beautiful headers, perfectly aligned data grids, and legible typography
- Optimized for **CA/Accounting audits** and formal record-keeping
- Share directly via **WhatsApp**, **Email**, or **Bluetooth printer**

### 🌐 Multi-Language Support
- Full localization in **3 languages**:
  - 🇬🇧 English
  - 🇮🇳 Hindi (हिंदी)
  - 🇮🇳 Gujarati (ગુજરાતી)
- Switch language on-the-fly from the app settings
- All UI labels, guides, and messages are fully translated

### 🎨 Premium UI/UX
- **Material 3** design system with custom amber/gold color scheme
- **Light & Dark Mode** with persistent theme preference
- Glassmorphic cards, frosted blur popups, and polished visual details
- Fluid page transitions powered by `flutter_animate`
- Animated splash screen with logo reveal
- Responsive table grids optimized for outdoor readability (granite yards, sunlight)

---

## 🏗️ Architecture

The project follows a **feature-first clean architecture** pattern:

```
lib/
├── main.dart                          # App entry point & theme configuration
├── core/
│   └── localization/
│       └── app_translations.dart      # i18n engine (EN, HI, GU)
└── features/
    ├── splash/                        # Animated splash screen
    │   └── presentation/screens/
    ├── auth/                          # PIN lock authentication
    │   └── presentation/screens/
    ├── home/                          # Dashboard, backup & restore
    │   └── presentation/screens/
    │       └── home_screen.dart       # Backup UI, import UI, stats dashboard
    ├── main/                          # Bottom navigation shell
    │   └── presentation/screens/
    ├── slabs/                         # Core measurement engine
    │   ├── data/models/               # Slab & Book data models
    │   ├── presentation/screens/      # Measurement, History & restore UI
    │   └── services/                  # Storage, backup & persistence layer
    │       ├── storage_service.dart   # JSON-based local storage
    │       └── backup_service.dart    # Differential backup & restore engine
    ├── stock/                         # Stock management module
    │   ├── data/models/               # StockEntry data model
    │   └── presentation/screens/      # Stock list, add/edit UI
    ├── settings/                      # App settings & preferences
    │   └── presentation/screens/
    └── about/                         # About Us & contact info
        └── presentation/screens/
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) 3.x (Dart 3.12+) |
| **Design System** | Material 3 with `ColorScheme.fromSeed` |
| **State Management** | `ValueNotifier` + Stateful Widgets |
| **Persistence** | Custom JSON-based local storage engine via `path_provider` |
| **Backup Engine** | Differential JSON backup to device `Documents/` folder |
| **Preferences** | `shared_preferences` for theme, language & PIN |
| **PDF Engine** | `pdf` + `printing` packages |
| **Animations** | `flutter_animate` for micro-interactions & popup transitions |
| **Sharing** | `share_plus` for cross-app sharing |
| **Date Handling** | `intl` for locale-aware formatting |
| **QR Codes** | `qr_flutter` for QR code generation |
| **File Access** | `file_picker` + `permission_handler` for storage access |

---

## 📱 App Screens

| Screen | Description |
|---|---|
| **Splash** | Animated logo reveal with smooth fade-in transition |
| **PIN Lock** | 4-digit security gate on app launch |
| **Home** | Dashboard with backup/restore controls, sync stats, app guide, and language selector |
| **New Book** | Form to create a measurement book (granite, party, plate, date) |
| **Measurement** | Core data-entry grid with auto-save and fill-down logic |
| **History** | Chronological list of all saved books with search, sync badges, and restore option |
| **Stock** | Full stock inventory management with add, edit, delete, search |
| **PDF Preview** | Full print-ready preview with share/export options |
| **Settings** | Theme toggle, language selection, PIN management |
| **About Us** | Company info and contact details |

---

## 🔄 Backup System — How It Works

Jamna Stone uses a sophisticated **differential local backup system** that works like a simplified version of cloud sync but entirely on your device's local storage:

### Backup Flow
```
1. Click "Backup" on Home Screen
   ↓
2. 🔍 Scanning Phase — Counts total books & stock, identifies unsynced items
   ↓
3. ☁️ Syncing Phase — Writes only new/modified data to Documents/Jamna Stone Backup/
   ↓
4. ✅ Success — Marks all items as synced, shows green checkmark animation
```

### Restore Flow
```
1. Click "Load Data" on Home Screen or History Screen
   ↓
2. 🔍 Scanning Phase — Reads backup folder, compares with current app data
   ↓
3. ☁️ Importing Phase — Imports ONLY missing items (differential merge)
   ↓
4. ✅ Success — New items added, duplicates skipped, page refreshed
```

### Backup Storage Location
```
📁 Internal Storage/
└── Documents/
    └── Jamna Stone Backup/
        └── backup_data.json    # Complete app data (books + stock)
```

> ⚠️ **Important:** The backup folder persists even if you uninstall the app, ensuring your data is always safe.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- Android Studio / VS Code with Flutter extension
- An Android device or emulator

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/PoojanPatel7/Jamna_stone_Calculator.git

# 2. Navigate to the project
cd Jamna_stone_Calculator

# 3. Install dependencies
flutter pub get

# 4. Run on a connected device
flutter run
```

### Building a Release APK

```bash
flutter build apk --release
```

The signed APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

> 💡 A pre-built APK (`Jamna_Stone_Calculator.apk`) is included in the repository root for quick testing.

---

## 📂 Project Structure

```
Jamna_stone_Calculator/
├── android/                # Android platform configuration
├── ios/                    # iOS platform configuration (unused)
├── assets/
│   └── images/
│       ├── logo.jpeg       # App logo (splash screen)
│       └── icone.jpeg      # Launcher icon source
├── lib/                    # Dart source code (see Architecture above)
├── test/                   # Unit & widget tests
├── pubspec.yaml            # Dependencies & asset declarations
├── analysis_options.yaml   # Lint rules
├── Jamna_Stone_Calculator.apk  # Pre-built release APK
└── README.md               # You are here!
```

---

## 📋 Version History

| Version | Date | Changes |
|---|---|---|
| **v1.0.2** | Aug 2026 | Smart local backup & restore system with differential sync, live process animations (scanning, syncing, success), button lock during processing, stock management module with PDF export, glassmorphic popup redesign with AnimatedSwitcher transitions, sync status badges on books & stock, backup data persistence through app uninstalls |
| **v1.0.1** | Jul 2026 | Stock management, PDF enhancements, UI polish |
| **v1.0.0** | Jun 2026 | Initial release — Measurement books, PDF export, PIN lock, multi-language support, dark/light theme |

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** this repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Code Style
- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Ensure `flutter analyze` passes with zero warnings
- Write descriptive commit messages

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Poojan Patel**
- GitHub: [@PoojanPatel7](https://github.com/PoojanPatel7)

---

<p align="center">
  <strong>⭐ If this project helped you, give it a star on GitHub! ⭐</strong>
</p>

<p align="center">
  <sub>Built with ❤️ using Flutter — Making stone management elegant, accurate, and stress-free.</sub>
</p>
