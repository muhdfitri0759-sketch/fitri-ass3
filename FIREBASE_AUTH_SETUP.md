# Firebase Authentication Setup Guide

## Masalah: Firebase Auth Error (Merah)

Error ini terjadi kerana Firebase Authentication belum dikonfigurasi dengan betul. Ikuti langkah-langkah berikut:

## Langkah 1: Enable Email/Password Authentication di Firebase Console

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project **smart-room-70ea4**
3. Pergi ke **Authentication** → **Sign-in method**
4. Klik **Email/Password**
5. Enable **Email/Password** (toggle ON)
6. Klik **Save**

## Langkah 2: Download google-services.json

1. Di Firebase Console, klik icon **Settings (⚙️)** → **Project settings**
2. Scroll ke bawah ke bahagian **Your apps**
3. Klik icon **Android** (atau tambah app jika belum ada)
4. Masukkan:
   - **Package name**: `com.example.smart_room`
   - **App nickname**: Smart Room (optional)
   - **Debug signing certificate SHA-1**: (optional untuk sekarang)
5. Klik **Register app**
6. Download **google-services.json**
7. Copy file tersebut ke: `android/app/google-services.json`

## Langkah 3: Tambah Google Services Plugin

File `android/app/build.gradle.kts` sudah dikonfigurasi dengan betul, tapi pastikan:

1. File `android/build.gradle.kts` ada buildscript untuk google-services
2. File `android/app/build.gradle.kts` apply plugin google-services

## Langkah 4: Get SHA-1 Certificate (Optional tapi recommended)

Untuk production, anda perlu register SHA-1:

```bash
# Windows
cd android
gradlew signingReport

# Atau
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copy SHA-1 dan tambah di Firebase Console → Project Settings → Your apps → Android app → SHA certificate fingerprints

## Langkah 5: Clean dan Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

## Troubleshooting

### Masih error selepas setup?
1. Pastikan `google-services.json` ada di `android/app/`
2. Pastikan Email/Password sudah enable di Firebase Console
3. Restart Android Studio/VS Code
4. Clean build: `flutter clean && flutter pub get`

### Error "FirebaseAuthHostApi"?
- Ini bermakna Firebase Auth belum properly configured
- Pastikan semua langkah di atas sudah dilakukan
- Check Firebase Console → Authentication → Users (untuk verify setup)

## Test

Selepas setup, cuba:
1. Run app
2. Klik "Sign Up"
3. Masukkan email dan password
4. Seharusnya berjaya create account

Jika masih error, check Serial Monitor atau Logcat untuk error details.


