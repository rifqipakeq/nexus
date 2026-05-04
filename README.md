## Tentang Nexus

**Nexus** adalah aplikasi mobile berbasis Flutter yang dirancang khusus untuk memantau dan mengelola portofolio aset kripto Anda di jaringan **Ethereum Sepolia Testnet**. Nexus menghadirkan fitur mulai dari autentikasi keamanan, integrasi asisten AI cerdas, hingga pengelolaan profil yang mudah digunakan.

---

## Fitur Utama

- **Keamanan Lapis Ganda**: Dilengkapi dengan sistem login, registrasi, dan autentikasi biometrik (sidik jari/pengenalan wajah) untuk perlindungan maksimal.
- **Manajemen Portofolio & Multi-Akun**: Pantau aset Anda dengan mudah dan beralih antar berbagai akun kripto secara instan melalui fitur _Account Switcher_.
- **Transaksi Cerdas & Cepat**: Kirim saldo Ethereum (ETH) di jaringan Sepolia dengan cepat menggunakan pemindaian _QR Code_.
- **Riwayat Transaksi Detail**: Lacak setiap jejak aktivitas transaksi Anda dengan tampilan riwayat yang terstruktur dan informatif.
- **Asisten AI & Gamifikasi**: Berinteraksi dengan Chatbot AI pintar (didukung Google Generative AI). Akses fitur premium AI ini dengan menyelesaikan Kuis edukatif berbasis token.
- **Privasi Berbasis Sensor (Safe Zone)**: Menggunakan geolokasi, sensor gerakan, dan sensor jarak (proximity) untuk mengaktifkan perlindungan privasi (misal: menyembunyikan saldo di tempat umum).
- **Notifikasi Proaktif**: Dapatkan pemberitahuan lokal (_local notifications_) untuk pembaruan penting mengenai aset dan akun Anda.
- **Penyimpanan Lokal Super Aman**: Menggunakan `Hive` dan `Flutter Secure Storage` untuk mengenkripsi dan menyimpan data sensitif secara offline (local-first approach).

---

## Teknologi

Proyek ini dibangun menggunakan teknologi dan _library_ terkini dalam ekosistem Flutter:

| Kategori              | Teknologi Utama                                            |
| :-------------------- | :--------------------------------------------------------- |
| **Framework**         | Flutter, Dart                                              |
| **State Management**  | [Riverpod](https://riverpod.dev/)                          |
| **Routing**           | GoRouter                                                   |
| **Penyimpanan Lokal** | Hive, Flutter Secure Storage                               |
| **Web3 & Kripto**     | web3dart                                                   |
| **Jaringan & HTTP**   | Dio, HTTP                                                  |
| **Sensor & Hardware** | Geolocator, Sensors Plus, Proximity Sensor, Mobile Scanner |
| **AI Integration**    | Google Generative AI                                       |
| **Push/Local Notif**  | Flutter Local Notifications                                |

---

## Prasyarat

Sebelum memulai, pastikan Anda telah menyiapkan _environment_ berikut:

- **Flutter SDK**: Versi `3.19.x` atau terbaru (sesuaikan dengan spesifikasi project).
- **IDE**: Android Studio, Visual Studio Code, atau IntelliJ IDEA.
- **Perangkat / Emulator**: Disarankan menggunakan perangkat fisik (Android/iOS) untuk mencoba fungsionalitas kamera (QR Scanner), autentikasi biometrik, dan sensor perangkat secara optimal.

---

## Jalankan Aplikasi

### 1. Kloning Repositori

```bash
git clone https://github.com/rifqipakeq/nexus
cd nexus
```

### 2. Instalasi Dependensi

```bash
flutter pub get
```

### 3. Konfigurasi Environment (`.env`)

Edit `.env`:

```env
ALCHEMY_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
GEMINI_API_KEY=YOUR_GEMINI_KEY
COINGECKO_BASE_URL=https://api.coingecko.com/api/v3
SAFE_ZONE_LAT=-7.801389
SAFE_ZONE_LNG=110.364444
SAFE_ZONE_RADIUS=500
```

### 4. Konfigurasi Android

**Minimum SDK** (`android/app/build.gradle`):

```gradle
android {
    defaultConfig {
        minSdk = 23
    }
}
```

**Permissions** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.VIBRATE" />
```

**MainActivity** (`android/app/src/main/kotlin/.../MainActivity.kt`):

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() { }
```

### 5. Konfigurasi IOS

Tambahkan ke `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is needed to scan QR codes</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is needed for safe zone verification</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used for biometric authentication</string>
```

### 6. Menjalankan Aplikasi

Gunakan perintah berikut untuk menjalankan di perangkat/emulator yang terhubung:

```bash
flutter run
```

Atau jalankan pada perangkat spesifik:

```bash
flutter devices
flutter run -d <device_id>
```

---

## Arsitektur

Proyek ini menggunakan struktur modular untuk kemudahan pemeliharaan (_maintainability_):

```text
lib/
├── core/             # Konfigurasi dasar: konstanta, router, tema, utilitas
├── data/             # Layer data: model, repository, API service, local storage
├── presentation/     # Layer UI: screens, widgets, state/providers
└── main.dart         # Entry point aplikasi
assets/               # File statis: gambar, ikon, dsb.
```

---

## Catatan Penting

- **Testnet Only**: Aplikasi ini saat ini dikonfigurasi menggunakan **Ethereum Sepolia Testnet**. Jangan gunakan kredensial atau _private key_ dari _mainnet_ yang memiliki dana riil untuk menghindari risiko kehilangan dana.
- **Izin Perangkat**: Saat pertama kali digunakan, aplikasi akan meminta izin untuk Kamera (QR), Lokasi (Safe Zone), dan Sensor Biometrik. Pastikan Anda mengizinkannya untuk pengalaman fitur yang lengkap.
- **Local-First Architecture**: Semua kredensial dan data penting pengguna dienkripsi dan disimpan secara mandiri dalam perangkat. Kami **tidak menyimpan** _private key_ Anda di server eksternal apa pun.
