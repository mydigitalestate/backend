CREATE OR REPLACE FUNCTION get_all_bookings(
  house_booking_id_param integer
)
RETURNS TABLE (house_booking_id integer, booking_id integer)
AS $$
DECLARE
  booking_record bookings%ROWTYPE;
BEGIN
  FOR booking_record IN SELECT * FROM public.bookings WHERE house_id = house_booking_id_param
  LOOP
    RETURN QUERY SELECT house_booking_id_param, booking_record.id;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_all_bookings(1);