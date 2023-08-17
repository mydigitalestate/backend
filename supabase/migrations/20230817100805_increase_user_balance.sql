CREATE OR REPLACE FUNCTION increase_user_balance()
RETURNS TRIGGER AS $$

BEGIN
  IF (NEW.destination !~ '^[0-9]+$' AND length(NEW.destination) < 20) THEN
    UPDATE Profiles
    SET balance = balance + NEW.amount
    WHERE username = NEW.destination;
  END IF;
  RETURN NEW;
END;


$$ LANGUAGE plpgsql;