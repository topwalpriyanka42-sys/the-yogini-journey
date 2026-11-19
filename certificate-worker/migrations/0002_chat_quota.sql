CREATE TABLE chat_quota (
  uid TEXT PRIMARY KEY,
  day TEXT NOT NULL,
  requests INTEGER NOT NULL CHECK (requests BETWEEN 1 AND 10)
);
