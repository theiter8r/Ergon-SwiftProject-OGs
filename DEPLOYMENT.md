# ERGON Backend Deployment Guide

## 1) Prerequisites

### Required Tooling
- Node.js 20 or newer.
- npm 10 or newer.
- Firebase CLI installed globally.

### Install and Verify
```bash
node -v
npm -v

npm install -g firebase-tools
firebase --version
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

## Production Safety Checklist
- Confirm you are deploying to `prod` project ID.
- Ensure `functions/` builds cleanly before deploy.
- Verify secrets exist in target project before function deploy.
- Confirm Firestore rules are deployed before app release.
- Smoke-test Auth, `users/{uid}` initialization, and one `daily_insights` write.
