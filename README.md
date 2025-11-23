# Aftaler og Regnskab

Aftaler og Regnskab is a Flutter application built for a single independent makeup artist.  
It consolidates:

- Appointment scheduling (interactive calendar and appointment list)
- Client and service management
- Basic financial overview (paid / unpaid appointments per month)

The app is designed for one admin user and backed by Firebase (Firestore, Storage and Authentication).

---

## Prerequisites

To run the project you need:

- [Flutter](https://flutter.dev/docs/get-started/install) (stable channel, 3.x recommended)  
  - Run `flutter doctor` to verify your setup.
- A recent version of:
  - Android Studio **or**
  - Visual Studio Code with Flutter/Dart extensions **or**
  - Xcode (for iOS only)
- A Firebase project with:
  - Cloud Firestore
  - Firebase Storage
  - Firebase Authentication (email/password)

The exact Dart/Flutter SDK constraints are listed in `pubspec.yaml`.

---

## 1. Getting the code

```bash
# 1) Clone the project
git clone https://github.com/Sezio27/aftaler_og_regnskab.git

# 2) Enter the project folder
cd aftaler_og_regnskab

# 3) Fetch Dart / Flutter dependencies
flutter pub get

# 4) Check that Flutter sees a device (emulator or phone)
flutter devices

# 5) Run the app on the first available device
flutter run
```

## 2. Logging in

The app uses phone number authentication. For evaluation, a fixed test account is configured:

- **Phone number:** `12345678`
- **Verification code:** `123456`

To log in:

1. Start the app using the commands above (`flutter run`).
2. On the login screen, enter the phone number `12345678` 
3. Request the verification code.
4. When prompted, enter `123456` as the authentication code.
5. After successful login, you will be taken to the main flow.

