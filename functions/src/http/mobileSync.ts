import { DecodedIdToken, getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";

import { DailyInsightDocument, DailyInsightDocumentWrite, UserDocumentCreate } from "../models";
import { getAdminApp, toDateKeyUtc } from "../utils";

const DEFAULT_ELO = 1200;
const DEFAULT_STREAK = 0;
const DATE_KEY_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const UID_REGEX = /^[A-Za-z0-9:_-]{6,128}$/;

interface UpsertUserProfileRequest {
  uid?: string;
  email?: string;
  display_name?: string | null;
  fcm_token?: string | null;
}

interface SubmitDailyInsightRequest {
  uid?: string;
  date_key?: string;
  risk_score: number;
  completed_microtask: boolean;
  mental_energy?: number;
  sleep_quality?: number;
  digital_disconnect?: number;
}

const isObject = (value: unknown): value is Record<string, unknown> => {
  return typeof value === "object" && value !== null && !Array.isArray(value);
};

const hasOwn = (value: Record<string, unknown>, key: string): boolean => {
  return Object.prototype.hasOwnProperty.call(value, key);
};

const isTenPointScore = (value: unknown): value is number => {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 10;
};

const buildDefaultUserDocument = (
  email: string,
  displayName: string | null,
  fcmToken: string | null
): UserDocumentCreate => ({
  email,
  display_name: displayName,
  current_elo: DEFAULT_ELO,
  streak_count: DEFAULT_STREAK,
  fcm_token: fcmToken,
  createdAt: FieldValue.serverTimestamp()
});

const parseBody = (body: unknown): Record<string, unknown> => {
  if (!isObject(body)) {
    return {};
  }

  return body;
};

const parseUid = (body: Record<string, unknown>): string | null => {
  const raw = body.uid;
  if (typeof raw !== "string") {
    return null;
  }

  const uid = raw.trim();
  if (!UID_REGEX.test(uid)) {
    return null;
  }

  return uid;
};

const readSingleHeaderValue = (headerValue: string | string[] | undefined): string | null => {
  if (typeof headerValue === "string") {
    return headerValue;
  }

  if (Array.isArray(headerValue) && headerValue.length > 0) {
    return headerValue[0] ?? null;
  }

  return null;
};

const parseBearerToken = (authorizationHeader: string | string[] | undefined): string | null => {
  const rawHeader = readSingleHeaderValue(authorizationHeader);
  if (!rawHeader) {
    return null;
  }

  const [scheme, token, ...extraParts] = rawHeader.trim().split(/\s+/);
  if (extraParts.length > 0) {
    return null;
  }

  if (!scheme || !token || scheme.toLowerCase() !== "bearer") {
    return null;
  }

  return token;
};

const verifyRequestAuthToken = async (
  authorizationHeader: string | string[] | undefined
): Promise<DecodedIdToken | null> => {
  const token = parseBearerToken(authorizationHeader);
  if (!token) {
    return null;
  }

  try {
    return await getAuth(getAdminApp()).verifyIdToken(token);
  } catch (error) {
    logger.warn("Invalid Firebase ID token on mobile sync endpoint.", {
      error
    });
    return null;
  }
};

export const upsertUserProfile = onRequest(
  {
    region: "us-central1",
    cors: true
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "Method not allowed" });
      return;
    }

    const decodedToken = await verifyRequestAuthToken(req.headers.authorization);
    if (!decodedToken) {
      res.status(401).json({ ok: false, error: "Missing or invalid Firebase ID token" });
      return;
    }

    const authenticatedUid = decodedToken.uid;

    const body = parseBody(req.body) as Partial<UpsertUserProfileRequest> & Record<string, unknown>;
    const hasRequestedUid = hasOwn(body, "uid");
    const requestedUid = parseUid(body);

    if (hasRequestedUid && !requestedUid) {
      res.status(400).json({ ok: false, error: "uid must be a non-empty identifier" });
      return;
    }

    if (requestedUid && requestedUid !== authenticatedUid) {
      res.status(403).json({ ok: false, error: "uid does not match authenticated user" });
      return;
    }

    const uid = authenticatedUid;

    const hasEmail = hasOwn(body, "email");
    const hasDisplayName = hasOwn(body, "display_name");
    const hasFcmToken = hasOwn(body, "fcm_token");

    let email = "";
    if (hasEmail) {
      if (typeof body.email !== "string") {
        res.status(400).json({ ok: false, error: "email must be a string" });
        return;
      }

      email = body.email.trim();
      if (email.length > 320) {
        res.status(400).json({ ok: false, error: "email is too long" });
        return;
      }
    }

    let displayName: string | null = null;
    if (hasDisplayName) {
      if (body.display_name !== null && typeof body.display_name !== "string") {
        res.status(400).json({ ok: false, error: "display_name must be a string or null" });
        return;
      }

      displayName = typeof body.display_name === "string" ? body.display_name.trim() : null;
      if (displayName && displayName.length > 80) {
        res.status(400).json({ ok: false, error: "display_name is too long" });
        return;
      }
      if (displayName === "") {
        displayName = null;
      }
    }

    let fcmToken: string | null = null;
    if (hasFcmToken) {
      if (body.fcm_token !== null && typeof body.fcm_token !== "string") {
        res.status(400).json({ ok: false, error: "fcm_token must be a string or null" });
        return;
      }

      fcmToken = typeof body.fcm_token === "string" ? body.fcm_token.trim() : null;
      if (fcmToken && fcmToken.length > 4096) {
        res.status(400).json({ ok: false, error: "fcm_token is too long" });
        return;
      }
      if (fcmToken === "") {
        fcmToken = null;
      }
    }

    const db = getFirestore(getAdminApp());
    const userRef = db.collection("users").doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(userRef);

        if (!existing.exists) {
          transaction.set(
            userRef,
            buildDefaultUserDocument(
              hasEmail ? email : "",
              hasDisplayName ? displayName : null,
              hasFcmToken ? fcmToken : null
            ),
            { merge: true }
          );
          return;
        }

        const updates: Record<string, string | null> = {};
        if (hasEmail) {
          updates.email = email;
        }
        if (hasDisplayName) {
          updates.display_name = displayName;
        }
        if (hasFcmToken) {
          updates.fcm_token = fcmToken;
        }

        if (Object.keys(updates).length > 0) {
          transaction.set(userRef, updates, { merge: true });
        }
      });

      res.status(200).json({ ok: true, uid });
    } catch (error) {
      logger.error("upsertUserProfile failed", { uid, error });
      res.status(500).json({ ok: false, error: "Failed to upsert user profile" });
    }
  }
);

export const submitDailyInsight = onRequest(
  {
    region: "us-central1",
    cors: true
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "Method not allowed" });
      return;
    }

    const decodedToken = await verifyRequestAuthToken(req.headers.authorization);
    if (!decodedToken) {
      res.status(401).json({ ok: false, error: "Missing or invalid Firebase ID token" });
      return;
    }

    const authenticatedUid = decodedToken.uid;

    const body = parseBody(req.body) as Partial<SubmitDailyInsightRequest> & Record<string, unknown>;
    const hasRequestedUid = hasOwn(body, "uid");
    const requestedUid = parseUid(body);

    if (hasRequestedUid && !requestedUid) {
      res.status(400).json({ ok: false, error: "uid must be a non-empty identifier" });
      return;
    }

    if (requestedUid && requestedUid !== authenticatedUid) {
      res.status(403).json({ ok: false, error: "uid does not match authenticated user" });
      return;
    }

    const uid = authenticatedUid;

    if (!isTenPointScore(body.risk_score)) {
      res.status(400).json({ ok: false, error: "risk_score must be between 0 and 10" });
      return;
    }

    if (typeof body.completed_microtask !== "boolean") {
      res.status(400).json({ ok: false, error: "completed_microtask must be boolean" });
      return;
    }

    const dateKey =
      typeof body.date_key === "string" && body.date_key.trim().length > 0
        ? body.date_key.trim()
        : toDateKeyUtc(new Date());

    if (!DATE_KEY_REGEX.test(dateKey)) {
      res.status(400).json({ ok: false, error: "date_key must use YYYY-MM-DD" });
      return;
    }

    const optionalScoreKeys: Array<keyof SubmitDailyInsightRequest> = [
      "mental_energy",
      "sleep_quality",
      "digital_disconnect"
    ];

    for (const key of optionalScoreKeys) {
      const value = body[key];
      if (value === undefined || value === null) {
        continue;
      }

      if (!isTenPointScore(value)) {
        res.status(400).json({ ok: false, error: `${key} must be between 0 and 10` });
        return;
      }
    }

    const riskScore = body.risk_score;
    const completedMicrotask = body.completed_microtask;

    const db = getFirestore(getAdminApp());
    const userRef = db.collection("users").doc(uid);
    const insightRef = userRef.collection("daily_insights").doc(dateKey);

    try {
      await db.runTransaction(async (transaction) => {
        const [userDoc, insightDoc] = await Promise.all([
          transaction.get(userRef),
          transaction.get(insightRef)
        ]);

        if (!userDoc.exists) {
          transaction.set(userRef, buildDefaultUserDocument("", null, null), { merge: true });
        }

        if (insightDoc.exists) {
          const existingInsight = insightDoc.data() as Partial<DailyInsightDocument>;
          if (existingInsight.processed_for_elo === true) {
            throw new Error("INSIGHT_ALREADY_PROCESSED");
          }
        }

        const payload: DailyInsightDocumentWrite = {
          risk_score: riskScore,
          completed_microtask: completedMicrotask,
          processed_for_elo: false,
          source: "ios",
          timestamp: FieldValue.serverTimestamp()
        };

        if (typeof body.mental_energy === "number") {
          payload.mental_energy = body.mental_energy;
        }
        if (typeof body.sleep_quality === "number") {
          payload.sleep_quality = body.sleep_quality;
        }
        if (typeof body.digital_disconnect === "number") {
          payload.digital_disconnect = body.digital_disconnect;
        }

        transaction.set(insightRef, payload, { merge: true });
      });

      res.status(200).json({ ok: true, uid, date_key: dateKey });
    } catch (error) {
      if (error instanceof Error && error.message === "INSIGHT_ALREADY_PROCESSED") {
        res.status(409).json({
          ok: false,
          error: "This daily insight has already been processed for ELO and cannot be overwritten."
        });
        return;
      }

      logger.error("submitDailyInsight failed", { uid, dateKey, error });
      res.status(500).json({ ok: false, error: "Failed to submit daily insight" });
    }
  }
);

export const verifyMobileAuth = onRequest(
  {
    region: "us-central1",
    cors: true
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "GET") {
      res.status(405).json({ ok: false, error: "Method not allowed" });
      return;
    }

    const decodedToken = await verifyRequestAuthToken(req.headers.authorization);
    if (!decodedToken) {
      res.status(401).json({ ok: false, error: "Missing or invalid Firebase ID token" });
      return;
    }

    res.status(200).json({
      ok: true,
      uid: decodedToken.uid,
      email: decodedToken.email ?? null,
      issued_at: decodedToken.iat,
      expires_at: decodedToken.exp
    });
  }
);
