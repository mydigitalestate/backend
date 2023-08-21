CREATE OR REPLACE FUNCTION get_invested_amount(houseid INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
  total NUMERIC;
BEGIN
  SELECT SUM(amount) INTO total
  FROM transactions
  WHERE destination = houseid::text;
  RETURN total;
END;
$$ LANGUAGE plpgsql;