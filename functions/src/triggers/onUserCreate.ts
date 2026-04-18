import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { auth } from "firebase-functions/v1";

import { UserDocumentCreate } from "../models";
import { getAdminApp } from "../utils/firebase";

const DEFAULT_ELO = 1200;
const DEFAULT_STREAK = 0;

const buildDefaultUserDocument = (email: string): UserDocumentCreate => ({
  email,
  display_name: null,
  current_elo: DEFAULT_ELO,
  streak_count: DEFAULT_STREAK,
  fcm_token: null,
  createdAt: FieldValue.serverTimestamp()
});

export const onUserCreate = auth.user().onCreate(async (user) => {
  const db = getFirestore(getAdminApp());
  const userRef = db.collection("users").doc(user.uid);
  const email = user.email ?? "";

  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(userRef);

    if (existing.exists) {
      logger.info("User profile already initialized; skipping.", {
        uid: user.uid
      });
      return;
    }

    transaction.set(userRef, buildDefaultUserDocument(email));
  });

  logger.info("User profile initialized successfully.", {
    uid: user.uid
  });
});
