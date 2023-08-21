CREATE OR REPLACE FUNCTION create_widthdraw_transaction(
  new_destination text,
  new_amount numeric,
  new_status text
)
RETURNS VOID AS
$$
BEGIN
  INSERT INTO transactions (source, destination, amount, status)
  VALUES (get_username(auth.uid()), new_destination, new_amount, new_status);
END;
$$
LANGUAGE plpgsql;
