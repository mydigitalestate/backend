CREATE OR REPLACE FUNCTION increase_user_balance()
RETURNS TRIGGER AS $$
BEGIN
  RETURN (
    (username = ANY(user_names) OR user_names IS NULL)
    AND (username IS NOT NULL)
  );
END;
$$ LANGUAGE plpgsql;