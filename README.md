# TrustTier Rider App

The worker side of TrustTier. The rider accepts jobs, proves each step
(Arrived, Started, Finished) and watches their trust score.

## Run

1. Open a terminal in this folder.
2. Get packages: flutter pub get
3. Run: flutter run

## Screens

- Jobs: Accept, Decline, and three proof buttons (Self-report, NFC tap, Badge signed)
- My score: trust ring, tier weights, recent events
- Badge: internet switch and Sync now (offline queue)

## How the score works

Each event multiplies the rider's odds by a weight for its proof type:
self-report 1.1, NFC tap 1.3, badge signed 1.8.
The weights are in TierInfo.lr in lib/main.dart.

## Using it with the real project

All data is fake and lives in the Store class in lib/main.dart.
The NFC and Badge buttons are simulated. Replace Store with calls to your
FastAPI service, and replace the proof buttons with real NFC and Bluetooth later.