const dbname = "libro";
const dbversion = 1;

const resourceSchema = """CREATE TABLE resources (
  resource_id TEXT PRIMARY KEY, 
  category TEXT NOT NULL,
  genre TEXT NOT NULL,
  title TEXT NOT NULL, 
  author TEXT NOT NULL,
  description TEXT,
  thumbnail TEXT,
  keywords TEXT,
  media_types TEXT NOT NULL,
  items TEXT NOT NULL,
  bookmark TEXT,
  server_id INTEGER,
  extra TEXT
);""";

const serverSchema = """CREATE TABLE servers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  root TEXT NOT NULL,
  auth TEXT,
  extra TEXT
);""";
