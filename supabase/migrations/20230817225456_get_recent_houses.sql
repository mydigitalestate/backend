CREATE OR REPLACE FUNCTION get_recent_houses()
RETURNS TABLE (title text, pics text[], cost numeric, period integer, location text) AS $$
BEGIN
  RETURN QUERY SELECT name as title, images as pics, price as cost, duration as period, address as location
  FROM Houses
  WHERE publishing_date BETWEEN (now() - INTERVAL '7 days') AND now()
  ORDER BY publishing_date DESC;
END;
$$ LANGUAGE plpgsql;