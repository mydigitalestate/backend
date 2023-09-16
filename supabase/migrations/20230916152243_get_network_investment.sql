CREATE OR REPLACE FUNCTION get_network_investment(
  user_name text DEFAULT get_username(auth.uid()),
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
) RETURNS DECIMAL AS $$
WITH RECURSIVE referred_users(username, invited_by) AS (
  SELECT username, invited_by, subscribed_at
  FROM public.referrals
  WHERE invited_by = user_name  AND subscribed_at BETWEEN start_date_val AND end_date_val
  UNION
  SELECT r.username, r.invited_by, r.subscribed_at
  FROM referred_users ru
  JOIN public.referrals r ON r.invited_by = ru.username
)
SELECT 
  COALESCE(SUM(get_total_investments(username, start_date_val, end_date_val)), 0) AS overall_investments
FROM referred_users;
$$ LANGUAGE SQL;