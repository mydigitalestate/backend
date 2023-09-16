CREATE OR REPLACE FUNCTION get_properties(
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
  personal_invested_amount numeric,
  total_investments numeric,
  total_profits json,
  invested_dates timestamptz[],
  profited_dates timestamptz[],
  is_locked boolean
)
AS $$
BEGIN
  RETURN QUERY SELECT 
    h.id as house_id,
    h.name as title, 
    h.images[1] as pic, 
    h.address as location,
    h.duration as duration,
    h.total_required as total_required,
    COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val), 0) as personal_invested_amount,
    COALESCE(get_invested_amount(h.id), 0) as total_investments,
    row_to_json(get_total_profits(h.id, get_username(auth.uid()), start_date_val, end_date_val)) as total_profits,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = get_username(auth.uid())
        AND t.destination = h.id::text
    ) as invested_dates,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = h.id::text 
        AND t.destination = get_username(auth.uid())
    ) as profited_dates,
    h.id IN (SELECT id FROM get_locked_investments()) as is_locked
  FROM houses h
  WHERE get_username(auth.uid()) = ANY(h.investors);

END;
$$ LANGUAGE plpgsql;