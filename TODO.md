# ERGON Backend Build Ledger

## Phase 0: Initialization & Local Dev Environment
- [x] Create Firebase backend scaffold with TypeScript Cloud Functions.
- [x] Configure local Firestore and Auth emulators in `firebase.json`.
- [x] Add root `.gitignore` entries for Node/Firebase/Xcode artifacts.
- [x] Add baseline Firestore rules and indexes files.
- [x] Create initial modular source layout under `functions/src/`.
- [x] Clean already-staged machine-specific artifacts from git index.

## Phase 1: Data Models & Security
- [x] Create strict Firestore interfaces in `functions/src/models/types.ts`.
- [x] Implement strict user-scoped Firestore security rules.
- [x] Add auth user-create trigger to initialize `users/{uid}` defaults.
- [x] Add shared Firebase Admin app initializer for modular trigger/cron reuse.

## Phase 2: ELO Math & Triggered Engine
- [x] Implement ELO helper in `functions/src/utils/eloCalculator.ts`.
- [x] Implement idempotent `onInsightWritten` trigger.
- [x] Use Firestore transaction for atomic ELO update + processed flag.
- [x] Add runtime payload guards to prevent malformed insight writes from breaking retries.

## Phase 3: Streak Monitor & FCM Cleanup
- [ ] Implement nightly scheduled streak check cron.
- [ ] Reset streak and apply ELO penalty for missed day.
- [ ] Send reminder push and delete stale `fcm_token` values.

## Phase 4: Developer Guide & Deployment Pipeline
- [ ] Create `DEPLOYMENT.md` with local/prod setup instructions.
- [ ] Document Firebase Secret Manager usage for sensitive keys.
- [ ] Add deployment command checklist for rules/indexes/functions.
- [ ] Provide iOS date formatting examples (`YYYY-MM-DD`).