# ERGON Backend Deployment Guide

## 1) Prerequisites

### Required Tooling
- Node.js 20 or newer.
- npm 10 or newer.
- Java 21 or newer (required by Firestore emulator).
- Firebase CLI installed globally.

### Install and Verify
```bash
node -v
npm -v
java -version

npm install -g firebase-tools
firebase --version
```

### macOS: Install Java (if missing)
If `java -version` reports no runtime found:

```bash
brew install openjdk@21

echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"' >> ~/.zshrc

source ~/.zshrc
java -version
```

### Authenticate Firebase CLI
```bash
firebase login
```

### Configure Project Aliases
Use explicit aliases so local and production commands are never mixed.

```bash
firebase use --add
```

Suggested aliases:
- `dev` -> your Firebase development project ID
- `prod` -> your Firebase production project ID

## 2) Run the Local Emulator Suite

From repository root:

```bash
cd functions
npm install
npm run build
cd ..

firebase emulators:start --only auth,firestore,functions
```

Expected local ports from [firebase.json](firebase.json):
- Auth emulator: `9099`
- Firestore emulator: `8080`
- Functions emulator: `5001`
- Emulator UI: `4000`

### Optional: Import/Export Emulator Data
```bash
firebase emulators:start --only auth,firestore,functions --import=./.emulator-data --export-on-exit
```

## 3) Secrets and Google Cloud API Keys

Never store API keys in source code, `.env`, or iOS bundles for server-side use.

Use Firebase Secret Manager for server secrets:

```bash
firebase functions:secrets:set OPENAI_API_KEY --project <your-prod-project-id>
firebase functions:secrets:set SOME_OTHER_API_KEY --project <your-prod-project-id>
```

Reference secrets in Cloud Functions (Node.js/TypeScript):

```ts
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";

const openAiApiKey = defineSecret("OPENAI_API_KEY");

export const secureFunction = onRequest(
  { secrets: [openAiApiKey] },
  async (_req, res) => {
    const key = openAiApiKey.value();
    res.status(200).send({ hasKey: Boolean(key) });
  }
);
```

## 4) Production Deployment Commands

Deploy in this order:

### A. Firestore Security Rules
```bash
firebase deploy --only firestore:rules --project <your-prod-project-id>
```

### B. Firestore Indexes
```bash
firebase deploy --only firestore:indexes --project <your-prod-project-id>
```

### C. Cloud Functions
```bash
firebase deploy --only functions --project <your-prod-project-id>
```

### One-shot Deploy (Optional)
```bash
firebase deploy --only firestore:rules,firestore:indexes,functions --project <your-prod-project-id>
```

## 5) Swift Date Format for `daily_insights` IDs (`YYYY-MM-DD`)

`daily_insights` documents must use UTC date keys with this exact format: `yyyy-MM-dd`.

### Swift Utility
```swift
import Foundation

func makeInsightDateKey(from date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
```

### Firestore Write Example (Swift)
```swift
import FirebaseFirestore

let db = Firestore.firestore()
let uid = "<firebase-auth-uid>"
let dateKey = makeInsightDateKey()

let payload: [String: Any] = [
    "risk_score": 4.7,
    "completed_microtask": true,
    "processed_for_elo": false,
    "timestamp": Timestamp(date: Date())
]

db.collection("users")
  .document(uid)
  .collection("daily_insights")
  .document(dateKey)
  .setData(payload, merge: true)
```

## 6) Mobile Sync Endpoints (Cloud Functions HTTP)

The Swift app now syncs to backend using HTTPS functions:

- `upsertUserProfile`
- `submitDailyInsight`

Both endpoints now require a Firebase ID token in the `Authorization` header:

```text
Authorization: Bearer <firebase-id-token>
```

Requests without a valid token are rejected with `401`.
If a request includes `uid`, it must match the token's `uid`.

### Token Source in iOS App

The app now fetches Firebase ID tokens automatically using anonymous Firebase Auth REST flows.

- Emulator mode: uses Auth emulator at `127.0.0.1:9099` (default API key fallback: `demo-key`).
- Production/custom mode: requires a Firebase Web API key.

In debug builds, configure this in Profile -> Backend Debug:

- Backend mode (Emulator/Production/Custom)
- Firebase Web API Key
- Optional manual ID token override

Use **Check** in the same panel to validate token status against backend `verifyMobileAuth` endpoint.

Default endpoint base URL in simulator mode:

```text
http://127.0.0.1:5001/ergon-dev/us-central1
```

Default endpoint base URL on device/release mode:

```text
https://us-central1-ergon-dev.cloudfunctions.net
```

The app debug panel (Profile -> Backend Debug) can switch endpoint mode:

- Emulator
- Production
- Custom URL

The same panel stores the Firebase ID token used by sync requests.

### Example: Upsert User Profile

```bash
curl -X POST http://127.0.0.1:5001/ergon-dev/us-central1/upsertUserProfile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <firebase-id-token>" \
  -d '{
    "uid": "local-device-uid-123",
    "display_name": "Raaj",
    "email": "",
    "fcm_token": null
  }'
```

### Example: Submit Daily Insight

```bash
curl -X POST http://127.0.0.1:5001/ergon-dev/us-central1/submitDailyInsight \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <firebase-id-token>" \
  -d '{
    "uid": "local-device-uid-123",
    "date_key": "2026-04-18",
    "risk_score": 4.8,
    "completed_microtask": true,
    "mental_energy": 6,
    "sleep_quality": 7,
    "digital_disconnect": 5
  }'
```

### Example: Verify Token

```bash
curl -X GET http://127.0.0.1:5001/ergon-dev/us-central1/verifyMobileAuth \
  -H "Authorization: Bearer <firebase-id-token>"
```

## Production Safety Checklist
- Confirm you are deploying to `prod` project ID.
- Ensure `functions/` builds cleanly before deploy.
- Verify secrets exist in target project before function deploy.
- Confirm Firestore rules are deployed before app release.
- Smoke-test Auth, `users/{uid}` initialization, and one `daily_insights` write.
