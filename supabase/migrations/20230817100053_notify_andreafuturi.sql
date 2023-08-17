CREATE OR REPLACE FUNCTION notify_andreafuturi()
RETURNS TRIGGER AS $$

BEGIN
  IF NEW.source = get_username(auth.uid()) AND LENGTH(NEW.destination) > 20 THEN
    INSERT INTO Notifications (usernames, title, message, value, link, color, image)
    VALUES ('{andreafuturi}', 'New withdrawal', 'New withdrawal by '||get_username(auth.uid())||' !', NEW.amount, get_username(auth.uid()), 'info', 'withdraw');
  END IF;

  RETURN NEW;
END;


$$ LANGUAGE plpgsql;