CREATE OR REPLACE FUNCTION get_house_name(house_id INTEGER)
RETURNS TEXT AS $$
DECLARE
  house_name TEXT;
BEGIN
  SELECT name INTO house_name FROM houses WHERE id = house_id;
  RETURN house_name;
END;
$$ LANGUAGE plpgsql;