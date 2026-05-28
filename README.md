# 🛡️ Safe Connect

> A hybrid emergency communication app — because safety shouldn't depend on a signal bar.

Safe Connect sends SOS alerts over **three channels simultaneously** (Bluetooth, Firebase push, and SMS), so help gets through even when the internet is down.

---

## ✨ Features

- **🆘 SOS Alert** — Hold to trigger a 5-second countdown, then auto-dispatches your GPS location via BLE broadcast, Firebase FCM, and SMS to all emergency contacts
- **💬 BLE Chat** — Encrypted peer-to-peer messaging over Bluetooth, no internet required
- **📞 Emergency Contacts** — Import from your phone's address book; used by both SMS and Firebase alerts
- **🏥 First Aid Chatbot** — Offline keyword-based guide covering CPR, burns, choking, fractures, and more
- **📍 GPS Location** — Every SOS includes a Google Maps link to your coordinates

---

## 🛠️ Built With

- **Flutter** (Dart ≥ 3.4) — Android & iOS
- **Firebase** — Cloud Messaging + Firestore
- **flutter_blue_plus** — BLE scanning & GATT chat
- **encrypt / pointycastle** — AES-256 CBC message encryption
- **geolocator** — GPS for SOS location
- **sqflite** — Local SOS log and contact storage
- **provider** — State management

---

## 🚀 Getting Started

```bash
git clone https://github.com/sharanyaka07/Safe_Connect.git
cd Safe_Connect
flutter pub get
flutter run          # requires a physical Android device for BLE
```

**Firebase setup:** Add your `google-services.json` to `android/app/` and enable Cloud Messaging + Firestore in the Firebase console.

---

## 📂 Structure

```
lib/
├── core/        # Services: BLE, encryption, GPS, SMS, notifications
├── data/        # SQLite models + Firebase FCM
└── features/
    ├── sos/         # SOS screen, contacts, history
    ├── chat/        # BLE conversation UI
    ├── bluetooth/   # Device scan & connect
    └── firstaid/    # Offline chatbot
```

---

## 🔒 Permissions Required

`BLUETOOTH_SCAN` · `BLUETOOTH_CONNECT` · `BLUETOOTH_ADVERTISE` · `ACCESS_FINE_LOCATION` · `SEND_SMS` · `READ_CONTACTS` · `POST_NOTIFICATIONS`

---
