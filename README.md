# NexusNode Lite – Web3 Testnet Portfolio App

A fully local, multi-account Flutter application for Ethereum Sepolia testnet portfolio management with hardware-backed biometric authentication, AI chatbot, and strict per-user data isolation.

> **v2.0** — Firebase has been completely removed. All authentication, storage, and notifications are handled locally on-device.

---

## 📁 Architecture Overview

```
lib/
├── core/
│   ├── constants.dart              # App constants + user-scoped key helpers
│   ├── env_config.dart             # Environment variable access
│   ├── theme.dart                  # Dark theme configuration
│   ├── router.dart                 # GoRouter navigation config
│   └── session_manager.dart        # Inactivity timeout widget
├── data/
│   ├── models/
│   │   └── user_account.dart       # User account data model
│   ├── local/
│   │   ├── local_database_service.dart  # (legacy, kept for reference)
│   │   └── user_scoped_storage.dart     # Per-user Hive box management
│   └── services/
│       ├── auth_service.dart            # Multi-account auth lifecycle
│       ├── password_service.dart        # PBKDF2-HMAC-SHA256 hashing
│       ├── biometric_auth_service.dart  # Hardware-backed biometric signatures
│       ├── security_service.dart        # AES-256 encryption + secure storage
│       ├── blockchain_service.dart      # Ethereum Sepolia wallet operations
│       ├── notification_service.dart    # Local-only notifications
│       ├── api_service.dart             # Dio HTTP client
│       ├── gemini_service.dart          # Google Gemini AI
│       ├── price_service.dart           # CoinGecko ETH price API
│       ├── location_service.dart        # GPS safe zone checking
│       └── motion_service.dart          # Shake detection
├── presentation/
│   ├── providers.dart                   # Riverpod providers
│   └── screens/
│       ├── login_screen.dart            # Local username/password login
│       ├── register_screen.dart         # Account registration
│       ├── biometric_screen.dart        # Hardware-backed biometric gate
│       ├── account_switcher_screen.dart # Multi-account switcher
│       ├── dashboard_screen.dart        # Main dashboard
│       ├── chat_screen.dart             # AI chatbot (Gemini)
│       ├── game_screen.dart             # Reaction mini-game
│       ├── scanner_screen.dart          # QR code scanner
│       ├── send_transaction_screen.dart # Send ETH (safe zone gated)
│       └── history_screen.dart          # Transaction history
└── main.dart                            # App entry point
```

---

## 🔐 Security Model

### Password Hashing
- **Algorithm**: PBKDF2-HMAC-SHA256
- **Iterations**: 100,000 (OWASP 2023 minimum recommendation)
- **Salt**: 32 bytes, cryptographically random, unique per user
- **Output**: 256-bit derived key
- **Storage**: Only the hash and salt are stored; plaintext passwords are never persisted
- **Verification**: Constant-time byte comparison prevents timing side-channel attacks

### Biometric Authentication
- **Package**: `biometric_signature` (replaces `local_auth`)
- **Key type**: Hardware-backed ECDSA P-256
- **Storage**: Private key in Secure Enclave (iOS) / StrongBox (Android)
- **Authentication**: Produces a verifiable cryptographic signature, not just a boolean
- **Per-user keys**: Each account gets a unique key alias (`nexus_user_{userId}`)
- **Fallback**: Graceful degradation to password-only if biometrics unavailable

### Encryption
- **Wallet private keys**: AES-256-CBC encrypted, stored in Flutter Secure Storage
- **Scoped keys**: Each user's encrypted private key is stored under `{userId}_encrypted_private_key`
- **Key material**: AES key and IV generated with `Random.secure()` and persisted in secure storage

### Anti-Enumeration
- Login with a nonexistent username still performs a full PBKDF2 hash computation to prevent response-time-based username enumeration attacks

---

## 🔄 Authentication Flow

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────┐
│  App Start   │────▶│  Check Session   │────▶│   Biometric   │
└─────────────┘     │  (Secure Store)  │     │  Verification │
                    └──────────────────┘     └───────┬───────┘
                           │ no session              │ success
                           ▼                         ▼
                    ┌──────────────┐          ┌─────────────┐
                    │  Login/      │          │  Dashboard   │
                    │  Register    │          │  (scoped)    │
                    └──────┬───────┘          └─────────────┘
                           │ success                 │
                           ▼                         │ logout
                    ┌──────────────┐                 │
                    │  Set Active  │◀────────────────┘
                    │  Session     │     ┌────────────────┐
                    └──────┬───────┘     │ Close user     │
                           │             │ Hive boxes     │
                           ▼             │ Invalidate     │
                    ┌──────────────┐     │ all providers  │
                    │  Open User   │     │ Clear session  │
                    │  Scoped      │     └────────────────┘
                    │  Storage     │
                    └──────────────┘
```

### Registration Flow
1. User enters username + password
2. System generates 32-byte random salt
3. Password hashed with PBKDF2-HMAC-SHA256 (100k iterations)
4. Optionally enrolls biometric keys (hardware ECDSA keypair)
5. `UserAccount` stored in Hive `accounts` box
6. Active session set in Flutter Secure Storage
7. User-scoped Hive boxes opened

### Login Flow
1. User enters username + password
2. System looks up user by username (case-insensitive)
3. Password re-hashed with stored salt
4. Hashes compared using constant-time comparison
5. On success: set active session → open user-scoped storage → biometric gate → dashboard

### Session Resume Flow
1. App checks for `active_user_id` in secure storage
2. If found, routes to biometric verification screen
3. Biometric signature verified → dashboard with user data loaded

---

## 🔒 Data Isolation Strategy

### The Problem (v1.0)
All users shared global Hive boxes (`wallet`, `chat`, `game`). User B would see User A's wallet address, chat history, and game scores after logging in.

### The Solution (v2.0)
Each user gets uniquely-named Hive boxes:

```
user_{userId}_wallet    ← wallet address, balance, notification tracking
user_{userId}_chat      ← AI chat history
user_{userId}_game      ← game score, high score, total games
prices                  ← shared (ETH price is the same for everyone)
```

### Isolation Guarantees

| Event | What Happens |
|-------|-------------|
| **Login** | `UserScopedStorage.openForUser(userId)` opens per-user boxes |
| **Usage** | All reads/writes go through scoped box references |
| **Logout** | Boxes flushed + closed, references nulled, all providers invalidated |
| **Switch** | Close old user's boxes → open new user's boxes |
| **Private key** | Stored as `{userId}_encrypted_private_key` in secure storage |

Accessing a closed box throws a `StateError`, preventing accidental cross-user reads.

---

## 🔔 Notification System (No Firebase)

Since there is no backend server, push notifications are not possible. Instead:

| Trigger | Method | Channel |
|---------|--------|---------|
| **ETH Sent** | Immediate on `sendTransaction` success | `nexus_transactions` |
| **ETH Received** | Balance polling (every 30s) detects increase | `nexus_transactions` |
| **Price Alert** | Price change detected on refresh | `nexus_price_alerts` |
| **Inactivity** | Session manager timeout | `nexus_session` |

### Deduplication
- `lastNotifiedBalance` tracked in user-scoped Hive box
- Only notifies if balance differs from last notification
- Balance decrease from sending is already covered by the immediate send notification

### Limitations
- Notifications only fire while the app process is alive
- No background polling without Firebase/WorkManager
- Incoming ETH detection depends on the polling interval (configurable via `AppConstants.balancePollInterval`)

---

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio or Xcode
- Git

### Step 1: Install Dependencies

```bash
cd nexus_node_lite
flutter pub get
```

### Step 2: Configure Environment Variables

Edit `.env`:

```env
ALCHEMY_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
GEMINI_API_KEY=YOUR_GEMINI_KEY
COINGECKO_BASE_URL=https://api.coingecko.com/api/v3
SAFE_ZONE_LAT=-7.801389
SAFE_ZONE_LNG=110.364444
SAFE_ZONE_RADIUS=500
```

### Step 3: Android Configuration

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

> ⚠️ `biometric_signature` requires `FlutterFragmentActivity` instead of `FlutterActivity`.

### Step 4: iOS Configuration (optional)

Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is needed to scan QR codes</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is needed for safe zone verification</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used for biometric authentication</string>
```

### Step 5: Run

```bash
flutter run
```

---

## 🔧 Features

| Feature | Implementation |
|---------|---------------|
| **Multi-Account Auth** | Local PBKDF2 hashing + biometric signatures |
| **Account Switching** | Seamless switch with biometric re-verification |
| **Session Persistence** | Auto-resume via secure storage |
| **Session Timeout** | Auto-logout after 10 min inactivity |
| **Data Isolation** | Per-user Hive boxes + scoped secure storage keys |
| **Wallet** | Generate ETH wallet, AES-256 encrypted private key |
| **Balance** | Fetch from Alchemy RPC, convert via CoinGecko |
| **Send ETH** | Only in GPS safe zone, with send notification |
| **Receive Detection** | Polling-based balance change notification |
| **QR Scanner** | Scan wallet addresses to autofill |
| **AI Chat** | Google Gemini, per-user history |
| **Reaction Game** | Score tracked per-user |
| **Shake Detect** | Toggle balance visibility |
| **Offline Support** | Cached prices/wallet/chat via Hive |

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `dio` | HTTP client |
| `hive` / `hive_flutter` | Local NoSQL database |
| `flutter_secure_storage` | Encrypted key-value storage |
| `encrypt` | AES-256 encryption |
| `cryptography` | PBKDF2 password hashing |
| `biometric_signature` | Hardware-backed biometric auth |
| `web3dart` | Ethereum blockchain interaction |
| `flutter_local_notifications` | Local notifications |
| `geolocator` | GPS location |
| `sensors_plus` | Accelerometer (shake detection) |
| `mobile_scanner` | QR code scanning |
| `flutter_dotenv` | Environment variables |
| `google_generative_ai` | Google Gemini AI |
| `uuid` | Unique ID generation |

---

## ⚠️ Known Limitations

1. **No push notifications**: Without Firebase/backend, notifications only work while the app is in the foreground or background (process alive). Incoming ETH detection relies on polling.

2. **No server-side signature verification**: The `biometric_signature` package is designed for client-server verification. Since we have no backend, we use signatures for local cryptographic proof of biometric presence, which is still stronger than `local_auth`'s boolean return.

3. **Transaction history is mocked**: In production, use Alchemy Enhanced API or Etherscan API for real transaction history.

4. **PBKDF2 vs Argon2**: We chose PBKDF2 because the `cryptography` package is well-maintained and Argon2 support in pure Dart is limited. PBKDF2 with 100k iterations is OWASP-compliant.

5. **No account deletion UI**: Account deletion is supported in `AuthService.deleteAccount()` but no UI is provided. Can be added to the account switcher screen.

6. **Safe zone coordinates**: Default is Yogyakarta, Indonesia. Change in `.env`.

7. **Testnet only**: All blockchain operations use Ethereum Sepolia. Test ETH has no monetary value.

---

## 🏗️ Trade-offs & Design Decisions

| Decision | Rationale |
|----------|-----------|
| PBKDF2 over bcrypt | `cryptography` package is actively maintained; no native bcrypt in Dart |
| Per-user Hive boxes over row-level isolation | Hive doesn't support queries; separate boxes guarantee complete isolation |
| Polling over WebSocket for balance detection | Simpler, no persistent connection needed, acceptable for testnet |
| `biometric_signature` over `local_auth` | Cryptographic proof > boolean; prevents API hooking attacks |
| Global prices box | ETH price is not user-specific; saves duplication |
| No background isolate for polling | Flutter limitation without Firebase; would require WorkManager integration |
