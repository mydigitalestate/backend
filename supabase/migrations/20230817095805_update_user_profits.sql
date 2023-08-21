CREATE OR REPLACE FUNCTION update_user_profits()
RETURNS TRIGGER AS $$

BEGIN
  IF (NEW.destination !~ '^[0-9]+$' AND length(NEW.destination) < 20 ) THEN
    UPDATE Profiles
    SET total_profits = total_profits + NEW.amount
    WHERE username = NEW.destination;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;