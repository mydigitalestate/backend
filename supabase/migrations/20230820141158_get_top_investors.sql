CREATE OR REPLACE FUNCTION get_top_investors(
  house_id int4,
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS TABLE (
  username text,
  avatar text,
  name text,
  personal_invested_amount numeric,
  required_amount numeric
)
AS $$
DECLARE
  req_amount numeric;
BEGIN
  SELECT total_required INTO req_amount FROM houses WHERE id = house_id;
  
  RETURN QUERY SELECT 
  p.username AS username,
    get_avatar(p.username) as avatar,
    COALESCE(INITCAP(p.display_name), INITCAP(p.username)) AS name,
    COALESCE(get_total_investments(house_id, p.username, start_date_val, end_date_val), 0) AS personal_invested_amount,
    req_amount AS required_amount
  FROM profiles_view p
  INNER JOIN houses h ON p.username = ANY(h.investors) AND h.id = house_id
  ORDER BY personal_invested_amount DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;