# NexusNode Lite — Einstein Branch

> **Flutter + Web3 local-first wallet app for Ethereum Sepolia Testnet**
> Branch: `einstein` | Network: Sepolia | Architecture: Riverpod + Hive + web3dart

---

## Features

### Core (pre-Einstein)
| Feature | Description |
|---|---|
| Multi-account auth | PBKDF2 + biometric, per-user Hive boxes |
| Ethereum wallet | Generate, send ETH via web3dart on Sepolia |
| Price ticker | ETH/USD, ETH/IDR, ETH/CNY via CoinGecko |
| Safe Zone | GPS-based balance auto-hide |
| Proximity hide | Sensor-based balance privacy |
| Shake to toggle | Motion-based balance visibility |
| QR receive | QR code for wallet address |
| Session timeout | 10-min inactivity auto-logout |

### Einstein Additions
| Feature | Description |
|---|---|
| **Real Tx History** | Etherscan Sepolia API — 50 latest transactions, cached in Hive |
| **Transaction Detail** | Full hash, from/to, gas, status, timestamp + Sepolia Explorer link |
| **ERC-20 Tokens** | LINK, UNI, USDC balances via web3dart `balanceOf()` on Sepolia |
| **Token Swap** | Simulated swap UI with quote, slippage, gas estimate, confirm dialog |
| **Crypto Quiz** | 20-question bank replacing the reaction game |
| **Quiz Tokens** | Earn 10 tokens/correct + streak bonus |
| **Premium Chatbot** | AI locked until 100 quiz tokens earned; 1 token/message consumed |
| **Premium Badge** | Dashboard shows token balance chip + PREMIUM badge |

---

## Architecture

```
UI (screens/)
  ↕ Riverpod StateProviders
Data Layer (providers.dart)
  ↕
Service Layer (services/)          ←→  External APIs
  TransactionService               →   Etherscan Sepolia API
  TokenService                     →   Alchemy RPC (web3dart ERC-20 calls)
  SwapService                      →   Simulated (0x-compatible interface)
  QuizService                      →   Embedded question bank
  BlockchainService                →   Alchemy RPC (ETH balance, send)
  GeminiService                    →   Google Gemini AI
  PriceService                     →   CoinGecko
  ↕
Local Layer (Hive boxes)
  user_{id}_wallet                 →   address, balance, tx_history_v2, premium, tokens
  user_{id}_chat                   →   chat history
  user_{id}_game                   →   quiz score, high score
  user_{id}_tokens                 →   ERC-20 token balance cache
  prices (global)                  →   ETH price cache
  accounts (global)                →   UserAccount maps
```

---

## Setup

### 1. Clone & Install
```bash
git clone <repo>
cd nexus_node_lite
git checkout einstein
flutter pub get
```

### 2. Configure `.env`
```env
# Required — Alchemy Sepolia RPC
ALCHEMY_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Required — Google Gemini (for AI chatbot)
GEMINI_API_KEY=your_gemini_api_key

# Optional but recommended — Etherscan (for real tx history)
# Get free key at: https://etherscan.io/register → API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key

# CoinGecko (default works without key)
COINGECKO_BASE_URL=https://api.coingecko.com/api/v3

# Safe zone (default: Yogyakarta)
SAFE_ZONE_LAT=-7.792400226750825
SAFE_ZONE_LNG=110.41625688022219
SAFE_ZONE_RADIUS=5000
```

### 3. Run
```bash
flutter run
```

> ⚠️ This app targets **Android** (tested). iOS requires additional entitlements for biometric and location.

---

## Ethereum APIs Used

| API | Purpose | Key Required |
|---|---|---|
| Alchemy Sepolia RPC | ETH balance, send tx, ERC-20 calls | Yes (free tier) |
| Etherscan Sepolia API | Real transaction history | Yes (free tier, 5 req/sec) |
| CoinGecko API | ETH price in USD/IDR/CNY | No (free public) |

---

## ERC-20 Tokens (Sepolia)

| Token | Address | Decimals |
|---|---|---|
| LINK | `0x779877A7B0D9E8603169DdbD7836e478b4624789` | 18 |
| UNI | `0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984` | 18 |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C4` | 6 |

> Get Sepolia test tokens from the [Chainlink Faucet](https://faucets.chain.link/sepolia).

---

## Premium System Flow

```
QuizScreen
  ↓ Complete quiz
  ↓ +10 tokens per correct answer
  ↓ +5 bonus for 3+ streak
  ↓ Total tokens saved to Hive (walletBox['quiz_tokens'])
  ↓ If tokens ≥ 100 → walletBox['is_premium'] = true
                     → isPremiumProvider updated
  ↓
ChatScreen
  ↓ isPremium == false → PremiumLockScreen (shows progress)
  ↓ isPremium == true  → Full NexusBot access
  ↓ Each AI message deducts 1 token
  ↓ If tokens reach 0 → premium revoked
```

---

## Hive Box Schema

### `user_{id}_wallet`
| Key | Type | Description |
|---|---|---|
| `address` | String | Wallet ETH address |
| `balance` | double | Last known ETH balance |
| `tx_history_v2` | List\<Map\> | Rich TxRecord list from Etherscan |
| `tx_last_fetched` | String | ISO timestamp of last Etherscan fetch |
| `is_premium` | bool | Chatbot premium status |
| `quiz_tokens` | int | Accumulated quiz tokens |
| `user_safe_zones` | List\<Map\> | Safe zone configs |
| `user_timezone` | String | Selected timezone |

### `user_{id}_tokens`
| Key | Type | Description |
|---|---|---|
| `token_list` | List\<Map\> | ERC-20 token balance cache |

---

## Project Structure

```
lib/
├── core/
│   ├── constants.dart          # App-wide constants + Etherscan URLs
│   ├── env_config.dart         # .env accessors
│   ├── erc20_abi.dart          # Minimal ERC-20 ABI
│   ├── router.dart             # GoRouter (includes /tx-detail, /swap)
│   ├── session_manager.dart    # Inactivity timeout
│   └── theme.dart
├── data/
│   ├── local/
│   │   └── user_scoped_storage.dart   # Hive box manager (all features)
│   ├── models/
│   │   ├── user_account.dart
│   │   ├── tx_record.dart             # ← NEW: Etherscan tx model
│   │   ├── token_balance.dart         # ← NEW: ERC-20 token model
│   │   └── swap_quote.dart            # ← NEW: Swap quote model
│   └── services/
│       ├── auth_service.dart
│       ├── blockchain_service.dart
│       ├── transaction_service.dart   # ← NEW: Etherscan fetch + cache
│       ├── token_service.dart         # ← NEW: ERC-20 balanceOf calls
│       ├── swap_service.dart          # ← NEW: Simulated swap logic
│       ├── quiz_service.dart          # ← NEW: Question bank + rewards
│       ├── gemini_service.dart
│       └── price_service.dart
└── presentation/
    ├── providers.dart                 # All Riverpod providers
    └── screens/
        ├── dashboard_screen.dart      # + ERC-20 list, quiz chip, swap card
        ├── chat_screen.dart           # + Premium gate, token counter
        ├── game_screen.dart           # REPLACED → Crypto Quiz
        ├── history_screen.dart        # REPLACED → Real Etherscan data
        ├── transaction_detail_screen.dart  # ← NEW
        ├── swap_screen.dart               # ← NEW
        └── biometric_screen.dart      # + Einstein state seed on login
```

---

## Sepolia Explorer

All transaction hashes link to:
```
https://sepolia.etherscan.io/tx/{hash}
```

---

## License

MIT — Testnet only, no real financial value.
