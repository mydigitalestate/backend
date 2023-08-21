CREATE OR REPLACE FUNCTION get_profits_from_network_lines(
  name text DEFAULT get_username(auth.uid()),
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS TABLE (
    level integer,
    profits numeric,
    usernames text[]
) AS $$
SELECT
  gn.level,
  SUM(t.amount) AS profits,
  array_agg(DISTINCT gn.username ORDER BY gn.username) AS usernames
FROM
  get_network(name, start_date_val, end_date_val) gn
  LEFT JOIN public.transactions t
    ON t.source = gn.username AND t.destination = name
    AND t.timestamp BETWEEN start_date_val AND end_date_val
GROUP BY
  gn.invited_by,
  gn.level
ORDER BY 
  gn.level;
$$ LANGUAGE SQL;