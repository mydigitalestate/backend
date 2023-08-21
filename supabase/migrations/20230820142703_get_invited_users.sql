CREATE OR REPLACE FUNCTION get_invited_users(
  username text DEFAULT get_username(auth.uid()),
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS TABLE(referred_username text, referred_at timestamp without time zone) AS $$
WITH RECURSIVE invited_by_users(referred_username, invited_at) AS (
  SELECT username, subscribed_at
  FROM public.referrals
  WHERE invited_by = username AND subscribed_at BETWEEN start_date_val AND end_date_val
  UNION
  SELECT r.username, r.subscribed_at
  FROM invited_by_users ru
  JOIN public.referrals r ON r.invited_by = ru.referred_username
)
SELECT referred_username, invited_at
FROM invited_by_users;
$$ LANGUAGE sql;