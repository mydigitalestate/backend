CREATE OR REPLACE FUNCTION send_apartament_ownership_ended_notification()
RETURNS TRIGGER AS $$
BEGIN

 INSERT INTO Notifications (usernames, title, message, image,link,icon)
    VALUES (NEW.investors, 'Apartament`s Ownership Ended','Click here to check performance of '|| NEW.name, NEW.images[1], 'investment/' || NEW.id,'performance');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;