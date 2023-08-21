CREATE OR REPLACE FUNCTION get_profits_for_every_house(
  username text DEFAULT get_username(auth.uid()),
  start_date_val date DEFAULT '1900-02-08'::date,
  end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS TABLE (house_id int, profit numeric)
AS $$
BEGIN

  RETURN QUERY
  SELECT bookings.house_id, SUM(transactions.amount) as profit
  FROM transactions
  JOIN bookings ON bookings.id::text = transactions.source
  WHERE transactions.destination = username
    AND transactions.timestamp BETWEEN start_date_val AND end_date_val
  GROUP BY bookings.id;
END;
$$ LANGUAGE plpgsql;