CREATE OR REPLACE FUNCTION get_username(uid uuid)
RETURNS text AS $$
BEGIN
  RETURN (
    SELECT username
    FROM profiles
    WHERE id = uid
  );
END;
$$ LANGUAGE plpgsql;
