# Jamna Stone & Slab Calculator 🪨

Welcome to the **Jamna Stone & Slab Calculator**! This is a professional-grade, cross-platform mobile application designed specifically for stone businesses, marble dealers, and granite traders to measure, calculate, and store slab and block measurements seamlessly.

## 📱 Features

1. **Slab Measurement Calculator** 📏
   - Easily enter Length and Width for slabs.
   - Automatically calculates total area in various units (Square Feet, Square Meters, Square Inches).
   - Real-time Undo & Redo tracking for rapid data entry!
   - Saves drafts so you never lose work on accident.

2. **Block Calculator** 🧊
   - Instantly calculate block volume and weight in tonnes based on Length, Width, Height, and standard density.
   - Saves calculation history for easy reference.

3. **Secure Records & History** 🔒
   - All measurements and books are securely stored locally on your device.
   - Set a 4-Digit PIN to secure your data from unauthorized access.
   - Complete Developer PIN reset functionality (`9009`).

4. **Professional PDF Reports** 📄
   - Export your entire "Slab Book" into a high-quality PDF report.
   - Beautiful headers, distinct grids, and large, legible font sizes.
   - Print or share instantly via WhatsApp or Email.

5. **Premium UI/UX** ✨
   - Beautiful glass-morphism designs, vibrant gradients, and smooth flutter animations.
   - Stunning Splash screen with logo animation.

## 🛠️ Technology Stack

- **Framework:** Flutter (Dart)
- **Local Storage:** SharedPreferences & Custom Storage Service
- **PDF Generation:** `pdf` & `printing` packages
- **Animations:** `flutter_animate`
- **State Management:** Core Flutter Stateful Widgets & Reactive tracking

## 🚀 How to Run Locally

1. Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/PoojanPatel7/Jamna_stone_Calculator.git
   ```
3. Navigate to the project directory:
   ```bash
   cd Jamna_stone_Calculator/slab_count
   ```
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Run the app:
   ```bash
   flutter run
   ```

## 📦 Building the Production APK

To generate a release-ready APK for Android devices:

```bash
flutter build apk --release
```
The compiled APK will be available in `build/app/outputs/flutter-apk/app-release.apk`.

---

*Designed and developed to make stone management elegant and easy!*
