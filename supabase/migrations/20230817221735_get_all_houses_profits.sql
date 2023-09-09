CREATE OR REPLACE FUNCTION get_all_houses_profits(
  username text DEFAULT get_username(auth.uid()),
  start_date date DEFAULT '1900-02-08'::date,
  end_date date DEFAULT '2900-02-08'::date
)
RETURNS numeric
AS $$
DECLARE
  total NUMERIC;
  booking_ids text[];
BEGIN
SELECT array_agg(id::text) INTO booking_ids
 FROM bookings;

  SELECT SUM(amount) INTO total 
  FROM transactions
WHERE source = ANY(booking_ids)
    AND destination = username
    AND timestamp BETWEEN start_date AND end_date;
  RETURN total;
END;
$$ LANGUAGE plpgsql;