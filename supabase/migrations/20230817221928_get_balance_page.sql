CREATE OR REPLACE FUNCTION get_balance_page(OUT balance numeric, OUT transactions json)
AS $$
DECLARE
  end_date DATE;
  start_date DATE;
BEGIN
  end_date := '2900-01-01';
  start_date := '1900-01-01';

  SELECT p.balance INTO balance
  FROM profiles p
  WHERE p.username = get_username(auth.uid());

  SELECT COALESCE(json_agg(t), '[]'::json) INTO transactions
  FROM (SELECT * FROM get_transactions()) t;

END;
$$ LANGUAGE plpgsql;