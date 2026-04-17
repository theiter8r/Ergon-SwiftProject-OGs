export interface UserDocument {
  email: string;
  current_elo: number;
  streak_count: number;
  fcm_token: string | null;
  createdAt: FirebaseFirestore.Timestamp;
}

export interface UserDocumentCreate {
  email: string;
  current_elo: number;
  streak_count: number;
  fcm_token: string | null;
  createdAt: FirebaseFirestore.FieldValue;
}

export interface DailyInsightDocument {
  risk_score: number;
  completed_microtask: boolean;
  processed_for_elo: boolean;
  timestamp: FirebaseFirestore.Timestamp;
}

export interface DailyInsightDocumentWrite {
  risk_score: number;
  completed_microtask: boolean;
  processed_for_elo: boolean;
  timestamp: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
}
