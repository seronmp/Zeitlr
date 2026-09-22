-- Zeiterfassungs-App: Supabase Schema
-- Kopiere diese SQL-Befehle in den SQL Editor von Supabase

-- ===============================
-- 1. TABELLE ERSTELLEN
-- ===============================
CREATE TABLE timesheets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  break_minutes INT DEFAULT 0,
  project TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===============================
-- 2. INDEXES FÜR PERFORMANCE
-- ===============================
CREATE INDEX timesheets_user_id_idx ON timesheets(user_id);
CREATE INDEX timesheets_date_idx ON timesheets(date);
CREATE INDEX timesheets_user_date_idx ON timesheets(user_id, date DESC);

-- ===============================
-- 3. ROW LEVEL SECURITY (RLS)
-- ===============================
ALTER TABLE timesheets ENABLE ROW LEVEL SECURITY;

-- Policy: Benutzer können nur ihre eigenen Einträge sehen
CREATE POLICY "Users can view own timesheets" 
ON timesheets FOR SELECT 
USING (auth.uid() = user_id);

-- Policy: Benutzer können nur ihre eigenen Einträge erstellen
CREATE POLICY "Users can create own timesheets" 
ON timesheets FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Policy: Benutzer können nur ihre eigenen Einträge aktualisieren
CREATE POLICY "Users can update own timesheets" 
ON timesheets FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Benutzer können nur ihre eigenen Einträge löschen
CREATE POLICY "Users can delete own timesheets" 
ON timesheets FOR DELETE 
USING (auth.uid() = user_id);

-- ===============================
-- 4. TRIGGER FÜR UPDATES
-- ===============================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_timesheets_updated_at BEFORE UPDATE
ON timesheets FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ===============================
-- 5. VIEWS FÜR REPORTS (OPTIONAL)
-- ===============================

-- Tägliche Stundensummen
CREATE OR REPLACE VIEW daily_hours AS
SELECT 
  user_id,
  date,
  COUNT(*) as entries,
  ROUND(CAST(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) - (break_minutes * 60)) / 3600.0 AS NUMERIC), 2) as total_hours
FROM timesheets
WHERE end_time IS NOT NULL
GROUP BY user_id, date
ORDER BY user_id, date DESC;

-- Wöchentliche Stundensummen
CREATE OR REPLACE VIEW weekly_hours AS
SELECT 
  user_id,
  DATE_TRUNC('week', date)::date as week_start,
  ROUND(CAST(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) - (break_minutes * 60)) / 3600.0 AS NUMERIC), 2) as total_hours
FROM timesheets
WHERE end_time IS NOT NULL
GROUP BY user_id, DATE_TRUNC('week', date)
ORDER BY user_id, week_start DESC;

-- Monatliche Stundensummen
CREATE OR REPLACE VIEW monthly_hours AS
SELECT 
  user_id,
  DATE_TRUNC('month', date)::date as month_start,
  ROUND(CAST(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) - (break_minutes * 60)) / 3600.0 AS NUMERIC), 2) as total_hours
FROM timesheets
WHERE end_time IS NOT NULL
GROUP BY user_id, DATE_TRUNC('month', date)
ORDER BY user_id, month_start DESC;

-- Nach Projekte
CREATE OR REPLACE VIEW hours_by_project AS
SELECT 
  user_id,
  project,
  COUNT(*) as entries,
  ROUND(CAST(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) - (break_minutes * 60)) / 3600.0 AS NUMERIC), 2) as total_hours
FROM timesheets
WHERE end_time IS NOT NULL AND project IS NOT NULL
GROUP BY user_id, project
ORDER BY user_id, total_hours DESC;

-- ===============================
-- 6. TEST-DATEN (OPTIONAL - SPÄTER LÖSCHEN)
-- ===============================
-- Hinweis: Diese Einträge sind nur zum Testen. 
-- Später mit echten Daten ersetzen.

-- Beispiel: Eintrag erstellen (mit echtem user_id ersetzen)
-- INSERT INTO timesheets (user_id, date, start_time, end_time, break_minutes, project, notes)
-- VALUES (
--   'REAL-USER-UUID-HERE',
--   '2024-01-15',
--   '2024-01-15 08:00:00+00',
--   '2024-01-15 17:00:00+00',
--   30,
--   'Büro',
--   'Meetings + Dokumentation'
-- );

-- ===============================
-- 7. ANHANG: NÜTZLICHE QUERIES
-- ===============================

-- Alle Einträge eines Benutzers in diesem Monat
-- SELECT * FROM timesheets 
-- WHERE user_id = 'USER-UUID'
-- AND DATE_TRUNC('month', date) = DATE_TRUNC('month', NOW())
-- ORDER BY date DESC;

-- Durchschnittliche tägliche Arbeitszeit
-- SELECT 
--   DATE_TRUNC('week', date) as week,
--   ROUND(AVG(CAST(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0 AS NUMERIC)), 1) as avg_hours
-- FROM timesheets
-- WHERE end_time IS NOT NULL
-- GROUP BY DATE_TRUNC('week', date)
-- ORDER BY week DESC;

-- Pause-Statistik
-- SELECT 
--   SUM(break_minutes) as total_break_minutes,
--   ROUND(SUM(break_minutes)::numeric / 60, 1) as total_break_hours,
--   ROUND(AVG(break_minutes)::numeric, 0) as avg_break_per_entry
-- FROM timesheets
-- WHERE break_minutes > 0;
