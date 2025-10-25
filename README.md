# 📻 Community Radio Funding Protocol

A Stacks blockchain smart contract enabling **patronage-based funding** for local and diaspora-run radio stations. Support your favorite community voices with transparent, decentralized funding! 🌍

## ✨ Features

- 🏠 **Station Registration**: Radio stations can register and create their presence
- 💰 **Subscription Model**: Listeners can subscribe with recurring STX payments
- 🚀 **Funding Campaigns**: Stations can launch targeted fundraising campaigns
- 📊 **Transparent Tracking**: All funding and contributions are publicly auditable
- 🔄 **Flexible Withdrawals**: Station owners can withdraw earned funds
- 🛡️ **Platform Fees**: Small platform fee (2.5% default) for sustainability

## 🚀 Quick Start

### For Radio Stations 📡

1. **Register Your Station**
   ```clarity
   (contract-call? .comm-radio-funding register-station 
     "KRFM Community Radio" 
     "Local news and music for the neighborhood"
     "San Francisco, CA")
   ```

2. **Create a Funding Campaign**
   ```clarity
   (contract-call? .comm-radio-funding create-campaign 
     u1                              ;; station-id
     "New Equipment Fund"            ;; title
     "Help us upgrade our broadcast equipment"  ;; description
     u50000000                       ;; target: 50 STX
     u1440)                          ;; duration: ~10 days
   ```

3. **Withdraw Your Funds**
   ```clarity
   (contract-call? .comm-radio-funding withdraw-station-funds 
     u1           ;; station-id
     u10000000)   ;; amount: 10 STX
   ```

### For Supporters/Patrons 🎧

1. **Subscribe to a Station**
   ```clarity
   (contract-call? .comm-radio-funding subscribe-to-station 
     u1          ;; station-id
     u1000000)   ;; amount: 1 STX
   ```

2. **Contribute to a Campaign**
   ```clarity
   (contract-call? .comm-radio-funding contribute-to-campaign 
     u1          ;; campaign-id
     u5000000)   ;; amount: 5 STX
   ```

3. **Unsubscribe if Needed**
   ```clarity
   (contract-call? .comm-radio-funding unsubscribe-from-station u1)
   ```

## 📖 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `register-station` | Register a new radio station | name, description, location |
| `subscribe-to-station` | Subscribe with recurring payment | station-id, amount |
| `unsubscribe-from-station` | Cancel subscription | station-id |
| `create-campaign` | Launch funding campaign | station-id, title, description, target, duration |
| `contribute-to-campaign` | Contribute to campaign | campaign-id, amount |
| `withdraw-station-funds` | Withdraw subscription earnings | station-id, amount |
| `withdraw-campaign-funds` | Withdraw campaign funds (after end) | campaign-id |
| `deactivate-station` | Disable station | station-id |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-station` | Get station details | Station info or none |
| `get-subscription` | Get subscription details | Subscription info or none |
| `get-campaign` | Get campaign details | Campaign info or none |
| `get-station-by-owner` | Find station by owner | Station info or none |
| `get-patron-stations` | Get user's subscribed stations | List of station IDs |
| `is-campaign-active` | Check if campaign is running | Boolean |
| `calculate-platform-fee` | Calculate fee for amount | Fee amount |

## 💡 Usage Examples

### Complete Station Setup Flow

```clarity
;; 1. Register station
(contract-call? .comm-radio-funding register-station 
  "Global Diaspora Radio" 
  "Connecting communities worldwide through music and culture"
  "Online/Diaspora")

;; 2. Create campaign for initial setup
(contract-call? .comm-radio-funding create-campaign 
  u1 
  "Launch Campaign" 
  "Help us get started with professional equipment and licensing"
  u100000000    ;; Target: 100 STX
  u2880)        ;; Duration: ~20 days

;; 3. After campaign ends, withdraw funds
(contract-call? .comm-radio-funding withdraw-campaign-funds u1)
```

### Patron Support Journey

```clarity
;; 1. Subscribe to support ongoing operations
(contract-call? .comm-radio-funding subscribe-to-station u1 u2000000) ;; 2 STX monthly

;; 2. Contribute extra to special campaigns
(contract-call? .comm-radio-funding contribute-to-campaign u1 u10000000) ;; 10 STX

;; 3. Check your supported stations
(contract-call? .comm-radio-funding get-patron-stations tx-sender)
```

## 🔧 Configuration

- **Platform Fee**: 2.5% (250 basis points) - adjustable by contract owner
- **Minimum Subscription**: 1 STX (1,000,000 µSTX) - adjustable by contract owner
- **Maximum Stations per Patron**: 50 stations

## 🏗️ Development

Built with [Clarinet](https://github.com/hirosystems/clarinet) for the Stacks blockchain.

### Testing
```bash
clarinet test
```

### Local Development
```bash
clarinet console
```

## 🤝 Contributing

Community radio thrives on collaboration! Feel free to:
- Report bugs 🐛
- Suggest features 💡
- Submit pull requests 🔄
- Help with documentation 📝

## 📜 License

Open source for the community! 🎉

---

*Built with ❤️ for community radio stations worldwide* 🌎📻
