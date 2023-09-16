CREATE OR REPLACE FUNCTION get_house_from_booking(booking_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
  house_id_val INTEGER;
BEGIN
  SELECT house_id INTO house_id_val FROM bookings WHERE id = booking_id;
  RETURN house_id_val;
END;
$$ LANGUAGE plpgsql;