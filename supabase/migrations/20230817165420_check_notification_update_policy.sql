CREATE OR REPLACE FUNCTION check_notification_update_policy(username text, user_names text[])
RETURNS boolean AS $$
BEGIN
  RETURN (
    (username = ANY(user_names) OR user_names IS NULL)
    AND (username IS NOT NULL)
  );
END;
$$ LANGUAGE plpgsql;
