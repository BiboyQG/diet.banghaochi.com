PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS food_templates (
  id TEXT PRIMARY KEY,
  meal_slot TEXT NOT NULL CHECK (meal_slot IN ('breakfast', 'lunch', 'dinner', 'snack', 'drink', 'supplement', 'other')),
  name TEXT NOT NULL,
  calories_kcal REAL NOT NULL CHECK (calories_kcal >= 0),
  carbs_g REAL NOT NULL CHECK (carbs_g >= 0),
  protein_g REAL NOT NULL CHECK (protein_g >= 0),
  fat_g REAL NOT NULL CHECK (fat_g >= 0),
  water_ml REAL NOT NULL CHECK (water_ml >= 0),
  notes TEXT,
  usage_count INTEGER NOT NULL DEFAULT 0 CHECK (usage_count >= 0),
  last_used_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS food_templates_deleted_at_idx ON food_templates(deleted_at);
CREATE INDEX IF NOT EXISTS food_templates_usage_idx ON food_templates(usage_count DESC, updated_at DESC);

INSERT OR IGNORE INTO food_templates (
  id,
  meal_slot,
  name,
  calories_kcal,
  carbs_g,
  protein_g,
  fat_g,
  water_ml,
  notes,
  usage_count,
  last_used_at,
  created_at,
  updated_at,
  deleted_at
) VALUES (
  'template-chipotle-bowl',
  'lunch',
  'Chipotle half barbacoa + honey chicken bowl',
  540,
  54.5,
  28.5,
  20.5,
  0,
  'White rice, fresh tomato salsa, romaine lettuce, sour cream, no beans.',
  0,
  NULL,
  datetime('now'),
  datetime('now'),
  NULL
);
