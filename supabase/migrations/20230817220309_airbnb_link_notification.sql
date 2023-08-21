CREATE OR REPLACE FUNCTION airbnb_link_notification()
RETURNS TRIGGER AS $$


BEGIN
  INSERT INTO Notifications (usernames, title, message, image, link, icon) 
  VALUES (NEW.investors, 'No have airbnb link', 'House ' || NEW.name || ' did not have an Airbnb link when set to ready',
  NEW.images[1], 'investment/' || NEW.id, 'airbnb');
  RETURN NEW;
END;


$$ LANGUAGE plpgsql;