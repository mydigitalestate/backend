CREATE OR REPLACE FUNCTION is_booking_from_house(booking_id integer, house_booking_id integer)
RETURNS boolean
AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM bookings WHERE id = booking_id AND house_id = house_booking_id);
END;
$$ LANGUAGE plpgsql;