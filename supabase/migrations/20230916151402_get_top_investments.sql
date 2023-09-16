CREATE OR REPLACE FUNCTION get_top_investments(
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
  personal_invested_amount numeric,
  total_investments numeric,
  total_profits json
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
      COALESCE(get_total_investments(h.id, username, start_date_val, end_date_val), 0) as personal_invested_amount,
      COALESCE(get_invested_amount(h.id), 0) as total_investments,
      (SELECT json_agg(k) FROM (
          SELECT * FROM get_total_profits(h.id, username, start_date_val, end_date_val)
      ) k) as total_profits
  FROM houses h
  WHERE username = ANY(h.investors)
  ORDER BY (SELECT COALESCE(SUM(my_profits + network_profits), 0) FROM get_total_profits(h.id, username, start_date_val, end_date_val)) DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;