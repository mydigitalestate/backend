CREATE OR REPLACE FUNCTION count_properties(username text DEFAULT get_username(auth.uid()))
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT investors)
    FROM houses
    WHERE username = ANY(investors)
  );
END;
$$ LANGUAGE plpgsql;
