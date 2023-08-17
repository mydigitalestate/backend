CREATE OR REPLACE FUNCTION create_house_ready_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.airbnb_link IS NULL OR NEW.airbnb_link = '' THEN
    RAISE EXCEPTION 'airbnb_link is not present';
  END IF;

  INSERT INTO Notifications (usernames, title, message, image, link, icon) 
  VALUES (NEW.investors, 'Ready For Bookings', NEW.name || ' is now available on Airbnb!', NEW.images[1], NEW.airbnb_link , 'airbnb');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
