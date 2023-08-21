CREATE OR REPLACE FUNCTION get_unread_notifications_count()
RETURNS integer AS $$
DECLARE
  user_created_at TIMESTAMPTZ;
  unread_count INTEGER;
BEGIN
  -- Get the creation timestamp of the user
  SELECT created_at INTO user_created_at FROM auth.users a WHERE a.id = auth.uid();

  -- Calculate the count of unread notifications
  SELECT COUNT(*)
  INTO unread_count
  FROM notifications n
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND (get_username(auth.uid()) NOT IN (SELECT unnest(n.read)))
    AND (n.date >= user_created_at);

  RETURN unread_count;
END;
$$ LANGUAGE plpgsql;
