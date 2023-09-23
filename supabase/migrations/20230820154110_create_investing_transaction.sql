CREATE OR REPLACE FUNCTION create_investing_transaction(
  new_destination text,
  new_amount numeric
  )
RETURNS VOID AS
$$
BEGIN
  INSERT INTO transactions (source, destination, amount)
  VALUES (get_username(auth.uid()), new_destination, new_amount);
END;
$$
LANGUAGE plpgsql;

