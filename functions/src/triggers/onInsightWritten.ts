import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { DailyInsightDocument, UserDocument } from "../models";
import { calculateElo } from "../utils/eloCalculator";
import { getAdminApp } from "../utils/firebase";

const DEFAULT_ELO = 1200;

const isValidRiskScore = (value: unknown): value is number => {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 10;
};

const isDailyInsightDocument = (value: unknown): value is DailyInsightDocument => {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const candidate = value as Partial<DailyInsightDocument>;

  return (
    isValidRiskScore(candidate.risk_score) &&
    typeof candidate.completed_microtask === "boolean" &&
    typeof candidate.processed_for_elo === "boolean"
  );
};

const getUserDefaults = () => ({
  email: "",
  current_elo: DEFAULT_ELO,
  streak_count: 0,
  fcm_token: null,
  createdAt: FieldValue.serverTimestamp()
});

export const onInsightWritten = onDocumentWritten(
  {
    document: "users/{uid}/daily_insights/{dateString}",
    region: "us-central1",
    retry: true
  },
  async (event) => {
    if (!event.data) {
      logger.warn("onInsightWritten invoked without event data.", {
        uid: event.params.uid,
        dateString: event.params.dateString
      });
      return;
    }

    const afterSnapshot = event.data.after;
    if (!afterSnapshot.exists) {
      logger.info("Insight was deleted; skipping ELO processing.", {
        uid: event.params.uid,
        dateString: event.params.dateString
      });
      return;
    }

    const userRef = afterSnapshot.ref.parent.parent;
    if (!userRef) {
      logger.error("Could not resolve parent user reference for insight document.", {
        uid: event.params.uid,
        dateString: event.params.dateString
      });
      return;
    }

    const insightRef = afterSnapshot.ref;
    const db = getFirestore(getAdminApp());

    await db.runTransaction(async (transaction) => {
      const [insightDoc, userDoc] = await Promise.all([
        transaction.get(insightRef),
        transaction.get(userRef)
      ]);

      if (!insightDoc.exists) {
        logger.info("Insight disappeared before transaction processing.", {
          uid: event.params.uid,
          dateString: event.params.dateString
        });
        return;
      }

      const insightData = insightDoc.data();
      if (!isDailyInsightDocument(insightData)) {
        logger.error("Insight payload invalid; skipping ELO mutation and marking processed.", {
          uid: event.params.uid,
          dateString: event.params.dateString,
          payload: insightData
        });
        transaction.update(insightRef, {
          processed_for_elo: true
        });
        return;
      }

      if (insightData.processed_for_elo) {
        logger.info("Insight already processed; idempotent exit.", {
          uid: event.params.uid,
          dateString: event.params.dateString
        });
        return;
      }

      if (!userDoc.exists) {
        transaction.set(userRef, getUserDefaults(), { merge: true });
      }

      const userData = userDoc.exists ? (userDoc.data() as UserDocument) : null;
      const currentElo =
        userData && typeof userData.current_elo === "number" ? userData.current_elo : DEFAULT_ELO;
      const currentStreak =
        userData && typeof userData.streak_count === "number" ? userData.streak_count : 0;

      const eloResult = calculateElo({
        currentElo,
        riskScore: insightData.risk_score,
        completedMicrotask: insightData.completed_microtask
      });

      const nextStreak = insightData.completed_microtask ? currentStreak + 1 : 0;

      transaction.set(
        userRef,
        {
          current_elo: eloResult.newElo,
          streak_count: nextStreak
        },
        { merge: true }
      );

      transaction.update(insightRef, {
        processed_for_elo: true
      });

      logger.info("Insight processed and ELO updated.", {
        uid: event.params.uid,
        dateString: event.params.dateString,
        previousElo: currentElo,
        eloDelta: eloResult.delta,
        nextElo: eloResult.newElo,
        nextStreak
      });
    });
  }
);
