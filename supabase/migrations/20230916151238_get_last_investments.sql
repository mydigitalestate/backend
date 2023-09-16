CREATE OR REPLACE FUNCTION get_last_investments(
  username text,
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS TABLE (
  house_id integer,
  title text,
  pic text,
  location text,
  duration integer,
  total_required numeric,
  total_profits json,
  personal_invested_amount numeric,
  total_investments numeric,
  last_transaction timestamptz
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    h.id AS house_id,
    h.name AS title,
    h.images[1] AS pic,
    h.address AS location,
    h.duration AS duration,
    h.total_required AS total_required,
    (
      SELECT json_agg(k)
      FROM (
        SELECT *
        FROM get_total_profits(h.id, username, start_date_val, end_date_val)
      ) k
    ) AS total_profits,
    COALESCE(get_total_investments(h.id, username, start_date_val, end_date_val), 0) AS personal_invested_amount,
    COALESCE(get_invested_amount(h.id), 0) AS total_investments,
    MAX(t.timestamp) AS last_transaction
  FROM houses h
  LEFT JOIN transactions t ON h.id::text = t.destination
  WHERE username = ANY(
    h.investors) AND t.source = username
  GROUP BY h.id, h.name
  ORDER BY last_transaction DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;