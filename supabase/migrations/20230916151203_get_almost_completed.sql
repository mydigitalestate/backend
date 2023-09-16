CREATE OR REPLACE FUNCTION get_almost_completed()
RETURNS TABLE (
  houseid int4,
  title text,
  pic text,
  invested numeric,
  reached int4,
  total numeric,
  period int4,
  location text
) AS $$
BEGIN
  RETURN QUERY SELECT
    h.id AS houseid,
    name as title,
    images[1] as pic, 
    COALESCE(get_total_investments(h.id, get_username(auth.uid()), '1900-02-08'::date,'2900-02-08'::date),0) as invested,
    amount_reached AS reached,
    total_required as total,             
    duration as period,
    address as location
  FROM Houses h
  LEFT JOIN profiles_view p ON p.username = ANY(h.investors)
  WHERE amount_reached >= total_required * 0.9 AND amount_reached != total_required AND p.username = ANY(h.investors)
  GROUP BY h.id,h.name,h.images,h.amount_reached,h.total_required,h.duration,h.address
  ORDER BY (amount_reached - total_required) DESC;
END;
$$ LANGUAGE plpgsql;