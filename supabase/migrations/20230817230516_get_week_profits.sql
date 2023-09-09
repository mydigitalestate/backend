CREATE OR REPLACE FUNCTION get_week_profits()
RETURNS TABLE(labels text[], amounts numeric[]) AS $$
DECLARE
  booking_ids text[];
  week_start_date date DEFAULT (date_trunc('week', (CURRENT_DATE)::timestamp with time zone))::date;
  week_end_date date DEFAULT ((date_trunc('week', (CURRENT_DATE)::timestamp with time zone) + '6 days'::interval))::date;
  profits_arr numeric[];
BEGIN
  SELECT array_agg(id::text) INTO booking_ids
  FROM bookings;

  profits_arr := ARRAY(
    SELECT COALESCE(SUM(transactions.amount), 0) AS profit
    FROM transactions
    JOIN bookings ON bookings.id::text = transactions.source
    WHERE transactions.destination = get_username(auth.uid())
      AND transactions.timestamp::date BETWEEN week_start_date AND week_end_date
      AND bookings.id::text = ANY (booking_ids)
    GROUP BY transactions.timestamp::date
    ORDER BY transactions.timestamp::date
  );

  labels := ARRAY(
    SELECT to_char(day, 'Day')
    FROM unnest(generate_series(week_start_date, week_end_date, '1 day'::interval)::date) AS day
  );

  amounts := profits_arr;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
