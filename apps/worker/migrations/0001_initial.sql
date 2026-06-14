PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS profile (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  sex TEXT NOT NULL CHECK (sex IN ('male', 'female')),
  age INTEGER NOT NULL CHECK (age > 0),
  height_cm REAL NOT NULL CHECK (height_cm > 0),
  current_weight_kg REAL NOT NULL CHECK (current_weight_kg > 0),
  timezone TEXT NOT NULL,
  activity_factor REAL NOT NULL CHECK (activity_factor > 0),
  training_exercise_kcal INTEGER NOT NULL CHECK (training_exercise_kcal >= 0),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_targets (
  id TEXT PRIMARY KEY,
  day_type TEXT NOT NULL UNIQUE CHECK (day_type IN ('training', 'rest')),
  burn_kcal INTEGER NOT NULL CHECK (burn_kcal >= 0),
  intake_kcal INTEGER NOT NULL CHECK (intake_kcal >= 0),
  deficit_kcal INTEGER NOT NULL,
  carbs_g INTEGER NOT NULL CHECK (carbs_g >= 0),
  protein_g INTEGER NOT NULL CHECK (protein_g >= 0),
  fat_g INTEGER NOT NULL CHECK (fat_g >= 0),
  water_ml INTEGER NOT NULL CHECK (water_ml >= 0),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS day_logs (
  id TEXT PRIMARY KEY,
  local_date TEXT NOT NULL UNIQUE,
  day_type TEXT NOT NULL CHECK (day_type IN ('training', 'rest')),
  burn_kcal INTEGER NOT NULL CHECK (burn_kcal >= 0),
  intake_target_kcal INTEGER NOT NULL CHECK (intake_target_kcal >= 0),
  deficit_target_kcal INTEGER NOT NULL,
  carbs_target_g INTEGER NOT NULL CHECK (carbs_target_g >= 0),
  protein_target_g INTEGER NOT NULL CHECK (protein_target_g >= 0),
  fat_target_g INTEGER NOT NULL CHECK (fat_target_g >= 0),
  water_target_ml INTEGER NOT NULL CHECK (water_target_ml >= 0),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS entries (
  id TEXT PRIMARY KEY,
  day_log_id TEXT NOT NULL REFERENCES day_logs(id) ON DELETE CASCADE,
  logged_at TEXT NOT NULL,
  meal_slot TEXT NOT NULL CHECK (meal_slot IN ('breakfast', 'lunch', 'dinner', 'snack', 'drink', 'supplement', 'other')),
  name TEXT NOT NULL,
  calories_kcal REAL NOT NULL CHECK (calories_kcal >= 0),
  carbs_g REAL NOT NULL CHECK (carbs_g >= 0),
  protein_g REAL NOT NULL CHECK (protein_g >= 0),
  fat_g REAL NOT NULL CHECK (fat_g >= 0),
  water_ml REAL NOT NULL CHECK (water_ml >= 0),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS body_weights (
  id TEXT PRIMARY KEY,
  local_date TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  weight_kg REAL NOT NULL CHECK (weight_kg > 0),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  summary TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS entries_day_log_id_idx ON entries(day_log_id);
CREATE INDEX IF NOT EXISTS entries_deleted_at_idx ON entries(deleted_at);
CREATE INDEX IF NOT EXISTS day_logs_local_date_idx ON day_logs(local_date);
CREATE INDEX IF NOT EXISTS body_weights_local_date_idx ON body_weights(local_date);
CREATE INDEX IF NOT EXISTS audit_events_entity_idx ON audit_events(entity_type, entity_id);

INSERT OR IGNORE INTO profile (
  id,
  display_name,
  email,
  sex,
  age,
  height_cm,
  current_weight_kg,
  timezone,
  activity_factor,
  training_exercise_kcal,
  created_at,
  updated_at
) VALUES (
  'profile',
  'Owner',
  'm13971212844@gmail.com',
  'male',
  25,
  170,
  70,
  'America/Chicago',
  1.2,
  650,
  datetime('now'),
  datetime('now')
);

INSERT OR IGNORE INTO daily_targets (
  id,
  day_type,
  burn_kcal,
  intake_kcal,
  deficit_kcal,
  carbs_g,
  protein_g,
  fat_g,
  water_ml,
  created_at,
  updated_at
) VALUES
  ('target-training', 'training', 2620, 2100, 520, 250, 140, 60, 3000, datetime('now'), datetime('now')),
  ('target-rest', 'rest', 1970, 1700, 270, 160, 140, 55, 2300, datetime('now'), datetime('now'));
