CREATE OR REPLACE FUNCTION deposit_notification()
RETURNS TRIGGER AS $$

BEGIN
  IF LENGTH(NEW.destination) < 20 AND LENGTH(NEW.source) > 20 THEN
    INSERT INTO Notifications (usernames, title, message, value, link, color,image) 
    VALUES (ARRAY[NEW.destination], 'Balance Deposit', 'Your deposit has arrived!', NEW.amount, 'balance','info','deposit');
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;