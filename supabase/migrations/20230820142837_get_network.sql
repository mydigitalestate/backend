CREATE OR REPLACE FUNCTION get_network(
    name text,
    start_date_val date,
    end_date_val date
)
RETURNS TABLE (
    username text,
    invited_by text,
    level integer,
    subscribed_at timestamptz
) AS $$
WITH RECURSIVE referred_users(username, invited_by, level, subscribed_at) AS (
  SELECT username, invited_by, 0, subscribed_at 
  FROM public.referrals
  WHERE username = name
  UNION ALL
  SELECT r.username, r.invited_by, ru.level + 1, r.subscribed_at
  FROM public.referrals r
  JOIN referred_users ru ON r.invited_by = ru.username
)
SELECT username, invited_by, level , subscribed_at
FROM referred_users
WHERE subscribed_at BETWEEN start_date_val AND end_date_val
  AND username <> name;
$$ LANGUAGE SQL;