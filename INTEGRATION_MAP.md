# ERGON Frontend-Backend Integration Map

## 1. Repository Topology

- Root repo: Firebase config, Firestore rules/indexes, Cloud Functions TypeScript project.
- Nested repo at `Ergon/`: iOS SwiftUI app and tests.

## 2. Frontend Surface (SwiftUI)

### App shell
- `Ergon/Ergon/ErgonApp.swift`: app entry, injects `AuthViewModel` and `EloViewModel`.
- `Ergon/Ergon/ContentView.swift`: onboarding gate and main tab shell.

### Core state and business logic
- `Ergon/Ergon/EloViewModel.swift`: app state, local persistence, risk updates, task completion, backend sync orchestration.
- `Ergon/Ergon/BurnoutAnalyzer.swift`: Core ML burnout prediction wrapper.
- `Ergon/Ergon/HealthKitManager.swift`: sleep/HRV authorization and retrieval.
- `Ergon/Ergon/Models.swift`: app domain models (`EloHistoryEvent`, `MicroTask`, `Milestone`, etc.).

### UI flows
- Home/dashboard: `Ergon/Ergon/HomeView.swift`
- Check-in sheet: `Ergon/Ergon/LogSheetView.swift`
- Analytics: `Ergon/Ergon/AnalyticsView.swift`
- Onboarding and profile capture: `Ergon/Ergon/OnboardingView.swift`
- Leaderboard/profile: `Ergon/Ergon/LeaderboardView.swift`, `Ergon/Ergon/ProfileView.swift`

### Integration adapter
- `Ergon/Ergon/BackendSyncService.swift`: HTTP sync to Cloud Functions.
- `Ergon/Ergon/FirebaseAuthTokenProvider.swift`: automatic Firebase Auth REST sign-in/refresh for ID tokens.
- `Ergon/Ergon/ProfileView.swift` (DEBUG): backend mode switcher + token/custom URL settings.

## 3. Backend Surface (Firebase Functions)

### Triggers and jobs
- `functions/src/triggers/onUserCreate.ts`: initializes `users/{uid}` document.
- `functions/src/triggers/onInsightWritten.ts`: processes ELO and streak from daily insight writes.
- `functions/src/crons/nightlyStreakCheck.ts`: nightly missed-day penalty and notification dispatch.

### HTTP ingress for mobile sync
- `functions/src/http/mobileSync.ts`
  - `upsertUserProfile`
  - `submitDailyInsight`
  - `verifyMobileAuth`
  - Firebase ID token verification (Bearer token)
  - uid/token consistency enforcement

### Shared contracts/utilities
- `functions/src/models/types.ts`: Firestore doc interfaces.
- `functions/src/utils/dateKey.ts`: UTC day key formatter (`yyyy-MM-dd`).

## 4. Contract Map

### users/{uid}
- `email: string`
- `display_name: string | null`
- `current_elo: number`
- `streak_count: number`
- `fcm_token: string | null`
- `createdAt: timestamp`

### users/{uid}/daily_insights/{yyyy-MM-dd}
- `risk_score: number (0...10)`
- `completed_microtask: boolean`
- `processed_for_elo: boolean`
- `mental_energy?: number (0...10)`
- `sleep_quality?: number (0...10)`
- `digital_disconnect?: number (0...10)`
- `source?: string`
- `timestamp: timestamp`

## 5. Fixed Mismatches

- Added mobile HTTP ingress to backend so frontend can sync without requiring Firebase iOS SDK setup first.
- Added backend-compatible payload models and sync client in Swift.
- Added deterministic UTC date-key generation in Swift matching backend and rules.
- Added frontend tracking for `completed_microtask` by day key so submitted insights map to trigger expectations.
- Expanded backend model interfaces and Firestore rules to support optional check-in metrics collected by UI.
- Added optional `display_name` profile field in user doc to map onboarding name capture.
- Preserved idempotency: once an insight is already `processed_for_elo == true`, HTTP updates are rejected.
- Added authenticated endpoint enforcement so unauthenticated writes are rejected.
- Added in-app debug controls for backend mode and token configuration.
- Added automatic Firebase Auth token acquisition in Swift (manual token override optional).
- Added lightweight backend token verification endpoint and debug indicator UI.

## 6. End-to-End Runtime Flow

1. App resolves backend endpoint mode (emulator/production/custom).
2. App obtains Firebase ID token automatically via Auth REST (or uses manual override token if provided).
3. App optionally verifies token via `verifyMobileAuth` for debug status display.
4. App calls `upsertUserProfile` with display name.
5. User completes optional microtask; app records completion date key.
6. User submits evening check-in.
7. App calls `submitDailyInsight` with risk and check-in metrics.
8. Firestore trigger `onInsightWritten` computes ELO and streak, marks `processed_for_elo=true`.
9. Nightly cron penalizes users missing current UTC day insight.

## 7. No-Miss Checklist

- [x] Date key format aligned frontend/backend (`yyyy-MM-dd`, UTC).
- [x] Insight field names aligned (`risk_score`, `completed_microtask`, `processed_for_elo`, `timestamp`).
- [x] Optional metrics accepted end-to-end (`mental_energy`, `sleep_quality`, `digital_disconnect`).
- [x] User profile field mapping includes `display_name`.
- [x] Function exports include triggers, crons, and HTTP endpoints.
- [x] Firestore rules updated to allow new optional fields while blocking client ELO mutation.
- [x] HTTP endpoints require valid Firebase ID token.
- [x] HTTP endpoints reject uid mismatch with authenticated token uid.
- [x] App includes debug controls for backend environment and token.
- [x] App auto-fetches/refreshes Firebase ID token when manual override is not set.
- [x] Debug panel token indicator calls backend verify endpoint.
- [x] Functions TypeScript build verified.
- [ ] Full iOS build/test in Xcode (blocked in current environment: full Xcode not installed).

## 8. Operational Notes

- Simulator default backend URL: `http://127.0.0.1:5001/ergon-dev/us-central1`.
- Device/release default backend URL: `https://us-central1-ergon-dev.cloudfunctions.net`.
- App debug settings persist endpoint mode (`emulator`/`production`/`custom`) and ID token.
- Legacy override key remains supported: `ergon_backend_base_url`.
