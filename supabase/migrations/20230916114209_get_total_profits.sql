CREATE OR REPLACE FUNCTION get_total_profits(
   h_id integer,
   username TEXT DEFAULT get_username(auth.uid()),
   start_date date DEFAULT '1900-02-08'::date,
   end_date date DEFAULT '2900-02-08'::date,
   OUT houseId integer,
   OUT my_profits NUMERIC,
   OUT network_profits NUMERIC
)
AS $$
DECLARE 
  my_profits_val NUMERIC := 0;
  network_profits_val NUMERIC := 0;
  booking_ids text[];
BEGIN
  SELECT ARRAY(
    SELECT b.id::text
    FROM bookings b
    WHERE b.house_id = h_id
  ) INTO booking_ids;

  SELECT COALESCE(SUM(t.amount), 0) INTO my_profits_val
  FROM transactions t
  WHERE t.source = ANY(booking_ids)
    AND t.destination = username
    AND t.timestamp BETWEEN start_date AND end_date;

  SELECT COALESCE(SUM(t.amount), 0) INTO network_profits_val
  FROM transactions t
  WHERE t.source = ANY(booking_ids)
    AND t.destination != username
    AND t.timestamp BETWEEN start_date AND end_date;

  houseId := h_id;
  my_profits := my_profits_val;
  network_profits := network_profits_val;
END;
$$ LANGUAGE plpgsql;