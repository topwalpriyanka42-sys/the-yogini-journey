CREATE TABLE certificates (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  course_id TEXT NOT NULL,
  learner_name TEXT NOT NULL,
  course_title TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  issued_at TEXT NOT NULL,
  share_enabled INTEGER NOT NULL DEFAULT 0 CHECK (share_enabled IN (0, 1)),
  UNIQUE (uid, course_id)
);
CREATE INDEX certificates_by_learner ON certificates(uid, issued_at DESC);
