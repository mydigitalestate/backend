CREATE OR REPLACE FUNCTION get_profits_from_each_user_network(
  start_date_val date ,
  end_date_val date,
   name text DEFAULT get_username(auth.uid())
)
RETURNS TABLE (
    username text,
    invited_by text,
    level integer,
    profits numeric
) AS $$
SELECT
  gn.username,
  gn.invited_by,
  gn.level,
  SUM(t.amount) AS profits
FROM
  get_network(name, '1900-02-08', '2900-02-08') gn
   JOIN public.transactions t
    ON t.source = gn.username AND t.destination = name  -- from users of his network
    -- ON t.source ~'^\d+$' AND t.destination = name  ---> from every user
    AND t.timestamp BETWEEN start_date_val AND end_date_val
GROUP BY
  gn.username,
  gn.invited_by,
  gn.level
  ORDER BY level;
$$ LANGUAGE SQL;