CREATE OR REPLACE FUNCTION decrease_user_balance()
RETURNS TRIGGER AS $$

BEGIN
  IF (NEW.source !~ '^[0-9]+$' AND length(NEW.source) < 20 AND 
  NEW.destination ~ '^[0-9]+$' OR length(NEW.destination) > 20)THEN
    UPDATE Profiles
    SET balance = balance - NEW.amount
    WHERE username = NEW.source;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;