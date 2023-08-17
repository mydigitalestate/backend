CREATE OR REPLACE FUNCTION send_new_apartment_notification()
RETURNS trigger AS $$
BEGIN
  INSERT INTO Notifications (title, message, image, link, icon)
  VALUES ('New Apartment Available', NEW.name || ' has been added to the market!', NEW.images[1], 'investment/' || NEW.id, 'market');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;