import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { UserDocument } from "../models";
import { toDateKeyUtc } from "../utils/dateKey";
import { getAdminApp } from "../utils/firebase";

const MISSED_DAY_ELO_PENALTY = 15;
const MIN_ELO = 100;

const isUnregisteredTokenError = (error: unknown): boolean => {
  if (typeof error !== "object" || error === null || !("code" in error)) {
    return false;
  }

  return (error as { code?: string }).code === "messaging/registration-token-not-registered";
};

export const nightlyStreakCheck = onSchedule(
  {
    schedule: "59 23 * * *",
    timeZone: "Etc/UTC",
    region: "us-central1"
  },
  async () => {
    const app = getAdminApp();
    const db = getFirestore(app);
    const messaging = getMessaging(app);

    const dateKey = toDateKeyUtc(new Date());
    const usersSnapshot = await db.collection("users").get();

    logger.info("Nightly streak check started.", {
      dateKey,
      userCount: usersSnapshot.size
    });

    let usersPenalized = 0;
    let notificationsSent = 0;
    let staleTokensCleared = 0;

    for (const userSnapshot of usersSnapshot.docs) {
      const uid = userSnapshot.id;

      try {
        const dailyInsightRef = userSnapshot.ref.collection("daily_insights").doc(dateKey);
        const dailyInsightSnapshot = await dailyInsightRef.get();

        if (dailyInsightSnapshot.exists) {
          continue;
        }

        const user = userSnapshot.data() as Partial<UserDocument>;
        const currentElo =
          typeof user.current_elo === "number" ? user.current_elo : 1200;
        const nextElo = Math.max(MIN_ELO, currentElo - MISSED_DAY_ELO_PENALTY);

        await userSnapshot.ref.set(
          {
            streak_count: 0,
            current_elo: nextElo
          },
          { merge: true }
        );

        usersPenalized += 1;

        const token = typeof user.fcm_token === "string" ? user.fcm_token : "";
        if (!token) {
          continue;
        }

        try {
          await messaging.send({
            token,
            notification: {
              title: "ERGON Reminder",
              body: "Your Bio-Aura needs calibrating!"
            },
            data: {
              type: "streak_reminder",
              date: dateKey
            }
          });
          notificationsSent += 1;
        } catch (error) {
          if (isUnregisteredTokenError(error)) {
            await userSnapshot.ref.update({
              fcm_token: FieldValue.delete()
            });
            staleTokensCleared += 1;

            logger.warn("Removed stale FCM token.", {
              uid,
              dateKey
            });
            continue;
          }

          logger.error("Failed to send streak reminder notification.", {
            uid,
            dateKey,
            error
          });
        }
      } catch (error) {
        logger.error("Nightly streak check failed for user.", {
          uid,
          dateKey,
          error
        });
      }
    }

    logger.info("Nightly streak check completed.", {
      dateKey,
      userCount: usersSnapshot.size,
      usersPenalized,
      notificationsSent,
      staleTokensCleared
    });
  }
);
