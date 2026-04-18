export interface UserDocument {
  email: string;
  display_name: string | null;
  current_elo: number;
  streak_count: number;
  fcm_token: string | null;
  createdAt: FirebaseFirestore.Timestamp;
}

export interface UserDocumentCreate {
  email: string;
  display_name: string | null;
  current_elo: number;
  streak_count: number;
  fcm_token: string | null;
  createdAt: FirebaseFirestore.FieldValue;
}

export interface DailyInsightDocument {
  risk_score: number;
  completed_microtask: boolean;
  processed_for_elo: boolean;
  mental_energy?: number;
  sleep_quality?: number;
  digital_disconnect?: number;
  source?: string;
  timestamp: FirebaseFirestore.Timestamp;
}

export interface DailyInsightDocumentWrite {
  risk_score: number;
  completed_microtask: boolean;
  processed_for_elo: boolean;
  mental_energy?: number;
  sleep_quality?: number;
  digital_disconnect?: number;
  source?: string;
  timestamp: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
}
