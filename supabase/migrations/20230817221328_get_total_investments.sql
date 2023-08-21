CREATE OR REPLACE FUNCTION get_total_investments( 
    house_id_val INTEGER,
    user_name TEXT DEFAULT get_username(auth.uid()),
    start_date_val DATE DEFAULT '1900-02-08'::date, 
    end_date_val DATE DEFAULT '2900-02-08'::date)
RETURNS NUMERIC AS $$
DECLARE
  invested_amount_val NUMERIC;
BEGIN
  SELECT SUM(amount) INTO invested_amount_val 
  FROM transactions
  WHERE source = user_name
    AND destination = house_id_val::text 
    AND timestamp >= start_date_val 
    AND timestamp <= end_date_val;

  RETURN invested_amount_val;
END;
$$ LANGUAGE plpgsql;
