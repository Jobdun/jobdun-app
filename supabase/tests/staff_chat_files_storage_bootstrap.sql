-- Managed storage schema absent from public snapshot; disposable DB only.
CREATE TABLE IF NOT EXISTS storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);

ALTER TABLE storage.buckets OWNER TO postgres;
