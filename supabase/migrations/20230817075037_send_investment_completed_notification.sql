CREATE OR REPLACE FUNCTION send_investment_completed_notification()
RETURNS TRIGGER AS $$

BEGIN
 INSERT INTO Notifications (usernames, title, message, image,link,icon,color)
    VALUES (NEW.investors, 'Investment Completed!', NEW.name || ' will soon be available in Airbnb!', NEW.images[1], 'investment/' || NEW.id,'party','success');

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;