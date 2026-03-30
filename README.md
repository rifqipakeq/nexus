# NexusNode Lite – Web3 Testnet Portfolio App

A fully functional Flutter mobile application demonstrating Web3 integration with Ethereum Sepolia testnet, AI chatbot, biometric auth, and more.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants.dart          # App-wide constants
│   ├── env_config.dart         # Environment variable access
│   ├── theme.dart              # Dark theme configuration
│   ├── router.dart             # GoRouter navigation config
│   └── session_manager.dart    # Inactivity timeout widget
├── data/
│   ├── local/
│   │   └── local_database_service.dart  # Hive DB operations
│   └── services/
│       ├── api_service.dart             # Dio HTTP client + interceptor
│       ├── security_service.dart        # AES encryption + biometrics + secure storage
│       ├── blockchain_service.dart      # Ethereum Sepolia wallet operations
│       ├── notification_service.dart    # Local + Firebase push notifications
│       ├── location_service.dart        # GPS safe zone checking
│       ├── motion_service.dart          # Shake detection via accelerometer
│       ├── gemini_service.dart          # Google Gemini AI via HTTP
│       └── price_service.dart           # CoinGecko ETH price API
├── presentation/
│   ├── providers.dart                   # Riverpod providers
│   └── screens/
│       ├── login_screen.dart            # Firebase email/password auth
│       ├── biometric_screen.dart        # Biometric verification gate
│       ├── dashboard_screen.dart        # Main dashboard with wallet & prices
│       ├── chat_screen.dart             # AI chatbot (Gemini)
│       ├── game_screen.dart             # Price Guess mini game
│       ├── scanner_screen.dart          # QR code wallet scanner
│       ├── send_transaction_screen.dart # Send ETH (safe zone gated)
│       └── history_screen.dart          # Transaction history (mocked)
└── main.dart                            # App entry point
```

---

## 🚀 Setup Instructions

### Prerequisites

- Flutter SDK (latest stable) installed
- Android Studio or Xcode for emulator/device
- Git

### Step 1: Clone & Install Dependencies

```bash
cd nexus_node_lite
flutter pub get
```

### Step 2: Configure Environment Variables

Edit the `.env` file in the project root with your API keys:

```env
ALCHEMY_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
GEMINI_API_KEY=YOUR_GEMINI_KEY
COINGECKO_BASE_URL=https://api.coingecko.com/api/v3
FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY
SAFE_ZONE_LAT=-7.801389
SAFE_ZONE_LNG=110.364444
SAFE_ZONE_RADIUS=500
```

---

### Step 3: Set Up Alchemy (Sepolia Testnet)

1. Go to [https://www.alchemy.com](https://www.alchemy.com)
2. Create a free account
3. Click **"Create App"**
4. Select:
   - Chain: **Ethereum**
   - Network: **Sepolia**
5. Copy the **HTTPS URL** from the app dashboard
6. Paste it into `.env` as `ALCHEMY_TESTNET_RPC`

**Get Test ETH:**

- Go to [https://sepoliafaucet.com](https://sepoliafaucet.com)
- Or use Alchemy's faucet: [https://www.alchemy.com/faucets/ethereum-sepolia](https://www.alchemy.com/faucets/ethereum-sepolia)
- Enter your wallet address to receive free test ETH

---

### Step 4: Set Up Firebase

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project (disable Google Analytics for simplicity)
3. **Add Android app:**
   - Package name: `com.nexusnode.nexus_node_lite`
   - Download `google-services.json`
   - Place it in `android/app/google-services.json`
4. **Add iOS app** (if needed):
   - Bundle ID: `com.nexusnode.nexusNodeLite`
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/GoogleService-Info.plist`
5. **Enable Authentication:**
   - Go to **Authentication** → **Sign-in method**
   - Enable **Email/Password**
6. **Enable Cloud Messaging:**
   - Go to **Cloud Messaging** tab
   - Note: FCM is automatically enabled for Firebase projects

**Android gradle setup:**

In `android/build.gradle`, ensure:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
}
```

In `android/app/build.gradle`, add at the bottom:

```gradle
apply plugin: 'com.google.gms.google-services'
```

---

### Step 5: Set Up Google Gemini API

1. Go to [https://aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Click **"Create API Key"**
3. Copy the key
4. Paste it into `.env` as `GEMINI_API_KEY`

> Note: Gemini API has a generous free tier. No credit card required.

---

### Step 6: Android-Specific Configuration

**Minimum SDK (android/app/build.gradle):**

```gradle
android {
    defaultConfig {
        minSdk = 23  // Required for biometrics + camera
    }
}
```

**Permissions (android/app/src/main/AndroidManifest.xml):**

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.VIBRATE" />
```

**For biometric auth, add to `AndroidManifest.xml` inside `<application>`:**

```xml
<meta-data
    android:name="io.flutter.embedding.android.NormalTheme"
    android:resource="@style/NormalTheme" />
```

---

### Step 7: iOS-Specific Configuration (if building for iOS)

**Info.plist additions:**

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is needed to scan QR codes</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is needed for safe zone verification</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used for biometric authentication</string>
```

---

### Step 8: Run the App

```bash
flutter run
```

---

## 🔧 Features Overview

| Feature                | Implementation                                             |
| ---------------------- | ---------------------------------------------------------- |
| **Authentication**     | Firebase Email/Password + biometric unlock                 |
| **Session Management** | Auto-logout after 10 min inactivity                        |
| **Wallet**             | Generate Ethereum wallet, encrypt private key with AES-256 |
| **Balance**            | Fetch from Alchemy Sepolia RPC, convert via CoinGecko      |
| **Send ETH**           | Only enabled inside GPS safe zone                          |
| **QR Scanner**         | Scan wallet addresses to autofill                          |
| **AI Chat**            | Google Gemini via HTTP POST, history stored locally        |
| **Price Game**         | Guess up/down, score tracked in Hive                       |
| **Shake Detect**       | Toggle balance visibility via accelerometer                |
| **Notifications**      | Local price alerts + inactivity reminders + FCM setup      |
| **Offline Support**    | Cached prices/wallet/chat via Hive                         |

---

## 🏗️ Architecture

Simplified Clean Architecture:

- **core/** – Constants, config, theme, routing, session management
- **data/** – Services (API, blockchain, security, etc.) and local storage
- **presentation/** – UI screens and Riverpod providers

No unnecessary abstraction layers. Code is readable for intermediate Flutter developers.

---

## 🔐 Session Management – How It Works

1. `SessionManager` widget wraps the entire app
2. A `GestureDetector` captures all taps, pans, and scale gestures
3. Each interaction resets a `Timer` set to 10 minutes
4. When the timer fires without reset, `onTimeout` callback triggers
5. The callback navigates to `/login`, effectively logging out the user
6. The timer restarts fresh on every new login

---

## ⚠️ Important Notes

- **TESTNET ONLY** – All blockchain operations use Ethereum Sepolia
- **No real money** – Test ETH has no monetary value
- **No backend server** – Everything runs from Flutter
- **Transaction history is mocked** – In production, use Alchemy/Etherscan API
- **Safe zone coordinates** – Default is Yogyakarta, Indonesia. Change in `.env`

---

## 📦 Dependencies

| Package                       | Purpose                         |
| ----------------------------- | ------------------------------- |
| flutter_riverpod              | State management                |
| go_router                     | Navigation                      |
| dio                           | HTTP client with interceptors   |
| hive / hive_flutter           | Local NoSQL database            |
| flutter_secure_storage        | Encrypted key-value storage     |
| encrypt                       | AES-256 encryption              |
| local_auth                    | Biometric authentication        |
| web3dart                      | Ethereum blockchain interaction |
| firebase_core / firebase_auth | Firebase authentication         |
| firebase_messaging            | Push notifications              |
| flutter_local_notifications   | Local notifications             |
| geolocator                    | GPS location                    |
| sensors_plus                  | Accelerometer (shake detection) |
| mobile_scanner                | QR code scanning                |
| flutter_dotenv                | Environment variables           |
