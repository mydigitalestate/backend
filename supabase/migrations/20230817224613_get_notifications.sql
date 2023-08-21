CREATE OR REPLACE FUNCTION get_notifications(
  start_date date DEFAULT '1900-02-08'::date,
  end_date date DEFAULT '2900-02-08'::date
)
RETURNS TABLE (
  id int4,
  title TEXT,
  image TEXT,
  message TEXT,
  date TIMESTAMPTZ,
  link TEXT,
  period TEXT,
  value TEXT,
  color TEXT,
  icon TEXT,
  read text[],
  usernames TEXT[]
) AS $$
DECLARE
  user_created_at TIMESTAMPTZ;
BEGIN
  SELECT created_at INTO user_created_at FROM auth.users a WHERE a.id = auth.uid();

  RETURN QUERY
  SELECT n.id, n.title, n.image, n.message, n.date, n.link,
    CASE
      WHEN (get_username(auth.uid()) NOT IN (SELECT unnest(n.read))) THEN 'UNREAD'
      WHEN n.date >= DATE_TRUNC('day', NOW()) THEN 'TODAY'
      WHEN n.date >= NOW() - INTERVAL '1 day' THEN 'YESTERDAY'
      WHEN n.date >= NOW() - INTERVAL '7 day' THEN 'THIS WEEK'
      WHEN n.date >= NOW() - INTERVAL '30 day' THEN 'THIS MONTH'
      ELSE 'OLDER'
    END as period,
    CASE
      WHEN n.value = 0.00 THEN '0.00'
      ELSE '+' || n.value::text
    END as value,
    n.color, n.icon, n.read, n.usernames
  FROM notifications n
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND (n.date >= COALESCE(user_created_at, start_date))
  ORDER BY n.date DESC
  LIMIT 100;

  -- Update the read array for unread notifications
  UPDATE notifications n
  SET read = array_append(COALESCE(n.read, '{}'), get_username(auth.uid()))
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND NOT EXISTS (
      SELECT 1
      FROM unnest(n.read) AS r
      WHERE r = get_username(auth.uid()) OR r IS NULL
    )
    AND (n.date BETWEEN start_date AND end_date OR start_date IS NULL OR end_date IS NULL);

END;
$$ LANGUAGE plpgsql;