# Jamna Stone & Slab Calculator 🪨

Welcome to the **Jamna Stone & Slab Calculator**! This is a highly optimized, cross-platform mobile application tailored for stone businesses, marble dealers, and granite traders. It enables seamless measurement, calculation, and secure storage of granite and marble slabs with an automated and intelligent workflow.

## 📱 Core Features

1. **Intelligent Slab Measurement 📏**
   - **Auto-Save & Live Persistence:** Measurements are saved instantly as you type. Never lose a single entry to app crashes or accidental closures.
   - **Smart "Fill-Down" Logic:** Automatically populates height/width gaps between slab entries to speed up repetitive data entry, making large book creations a breeze!
   - **Real-Time Area Calculation:** Instantly calculates total area in Square Feet, Square Meters, and Square Inches.
   - **Undo & Redo System:** Quickly revert or restore actions during rapid data entry.

2. **Secure Records & History 🔒**
   - **Local Storage Engine:** All books and measurements are securely stored right on your device for absolute privacy and offline accessibility.
   - **PIN Protection:** Set a 4-Digit PIN to lock your application and protect sensitive business data.
   - **Developer Recovery:** Built-in secure PIN reset functionality to prevent permanent lockouts (`9009`).

3. **Professional PDF Reporting 📄**
   - Export your entire "Slab Book" into an ultra-high-quality, professional PDF document.
   - Beautiful headers, meticulously aligned distinct grids, and optimally sized legible fonts suitable for CA/Accounting audits.
   - Instantly share or print via WhatsApp, Email, or connected Bluetooth printers.

4. **Premium UI/UX ✨**
   - **Aesthetic Excellence:** Beautiful glass-morphism designs, vibrant but professional gradients, and deeply polished aesthetics.
   - **Fluid Animations:** Smooth Flutter animations, page transitions, and an elegant Splash screen with logo animation.
   - **Responsive Table UI:** Upgraded data grids specifically optimized for maximum scannability and readability in bright outdoor environments (e.g., at the granite yard).

## 🛠️ Technology Stack

- **Framework:** Flutter (Dart)
- **State & Data Management:** Core Flutter Stateful Widgets, Reactive state tracking, and Custom JSON-based Storage Engine.
- **Reporting Engine:** `pdf` & `printing` packages
- **Animations:** `flutter_animate`

## 🚀 Getting Started

### Prerequisites
Make sure you have [Flutter](https://flutter.dev/docs/get-started/install) installed on your system.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/PoojanPatel7/Jamna_stone_Calculator.git
   ```

2. **Navigate to the project directory:**
   ```bash
   cd Jamna_stone_Calculator/slab_count
   ```

3. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

## 📦 Building the Production APK

To generate a fully-optimized, future-proof release APK for Android devices:

```bash
flutter build apk --release
```
The compiled, ready-to-distribute APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

*Designed and developed to make stone management elegant, accurate, and completely stress-free!*
