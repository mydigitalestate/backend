CREATE OR REPLACE FUNCTION update_amount_reached()
RETURNS TRIGGER AS $$


BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    UPDATE Houses
    SET amount_reached = amount_reached + NEW.amount
    WHERE id = (NEW.destination)::integer;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;