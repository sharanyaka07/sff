# 🛡️ Safe Connect

> A hybrid emergency communication app — because safety shouldn't depend on a signal bar.

Safe Connect sends SOS alerts over **three channels simultaneously** (Bluetooth, Firebase push, and SMS), so help gets through even when the internet is down.

---

## ✨ Features

🆘 Multi-Channel SOS Alert — sends via Bluetooth, SMS & Firebase simultaneously
🔐 AES-256 End-to-End Encrypted Chat — secure messaging over Bluetooth
☁️ Firebase Cloud Backend — real-time data storage across all devices
📍 GPS Location Sharing — auto-captures coordinates and shares Google Maps link during SOS
👥 Emergency Contacts — notifies contacts via SMS instantly
🗑️ Delete for Me / Delete for Everyone — WhatsApp-style message deletion
🏥 Built-in First Aid Guide — accessible offline
🔔 Push Notifications — via Firebase Cloud Messaging
💾 Offline Storage — SQLite local database for offline use
📱 Cross-Device Support — works across multiple devices simultaneously



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
requisites


Flutter SDK installed
Android Studio or VS Code
Android phone with USB debugging enabled
Firebase project set up


Steps


Clone the repository


bashgit clone https://github.com/sharanyaka07/safe-connect.git


Navigate to project folder


bashcd safe-connect


Install dependencies


bashflutter pub get


Add your google-services.json file to android/app/
Run the app


bashflutter run


🏗️ Project Structure

lib/
├── core/
│   ├── services/

---

---

## 🚀 How to Run

### Prerequisites
- Flutter SDK installed
- Android Studio or VS Code
- Android phone with USB debugging enabled
- Firebase project set up

### Steps

1. Clone the repository
```bash
git clone https://github.com/sharanyaka07/safe-connect.git
```

2. Navigate to project folder
```bash
cd safe-connect
```

3. Install dependencies
```bash
flutter pub get
```

4. Add your `google-services.json` file to `android/app/`

5. Run the app
```bash
flutter run
```

---

## 🏗️ Project Structure

```
lib/
├── core/
│   ├── services/        # Encryption, GPS, Notifications
│   ├── theme/           # App theme and colors
│   └── utils/           # Logger, Permissions
├── data/
│   ├── local/           # SQLite database and models
│   └── remote/          # Firebase services
└── features/
    ├── bluetooth/        # Bluetooth controller and screen
    ├── chat/             # Chat controller and screens
    ├── home/             # Home screen and controller
    ├── sos/              # SOS controller and screen
    └── firstaid/         # First Aid guide
```

---


---

## 📄 License

This project is developed for educational purposes as part of BCA Final Year Major Project.

---

⭐ If you like this project, give it a star on GitHub!
