# CrtMu

This repository now contains two parts:

- A Flutter client in the project root
- A minimal Node.js backend in `backend/`

## Frontend

The Flutter app is the user-facing chat experience.

Useful commands:

- `flutter pub get`
- `flutter run`
- `flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:3000`
- `flutter build ipa --release --dart-define=BACKEND_BASE_URL=https://api.your-domain.com`

For iOS release preparation, see `APPSTORE_CHECKLIST.md`.

For Android emulators, use `http://10.0.2.2:3000` instead of `127.0.0.1`.
For a real phone on the same Wi-Fi, use your computer's LAN IP.

## Backend

The backend is the bridge between Flutter and the future AI provider:

`Flutter -> backend -> model provider`

Useful commands:

- `cd backend`
- `npm install`
- `npm run dev`

For production deployment notes, see `backend/DEPLOYMENT.md`.

Available endpoints:

- `GET /health`
- `POST /chat`

## Why this structure

We keep the model key out of the mobile app and centralize request logging,
timeouts, uploads, and future billing logic in the backend.
