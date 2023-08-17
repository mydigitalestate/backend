CREATE OR REPLACE FUNCTION validate_transaction_amount()
RETURNS TRIGGER AS $$

DECLARE
  remaining_amount NUMERIC;
BEGIN
  IF NEW.source =  get_username(auth.uid())  AND EXISTS (
SELECT 1 FROM houses WHERE id::text = NEW.destination
  ) THEN
    SELECT total_required - COALESCE(get_invested_amount(id),0) INTO remaining_amount
    FROM houses
    WHERE id = CAST(NEW.destination AS INTEGER);

    IF NEW.amount > remaining_amount THEN
      RAISE EXCEPTION 'Transaction amount exceeds missing amount for the destination house';
    END IF;
  END IF;

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;