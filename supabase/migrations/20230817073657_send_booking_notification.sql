CREATE OR REPLACE FUNCTION send_booking_notification()
RETURNS TRIGGER AS $$
DECLARE
  house_images VARCHAR(255)[];
  house_image VARCHAR(255);
  nights INT;
  value DECIMAL(10,2);
  total INT;
  house_name VARCHAR(255);
  night_plural TEXT; -- Added variable for pluralization
BEGIN
  SELECT images, name, total_required INTO house_images, house_name, total FROM Houses WHERE id = NEW.house_id;
  nights := DATE_PART('day', NEW.end_date - NEW.start_date);
  house_image := house_images[1];
  
  -- Determine pluralization for 'night(s)'
  IF nights = 1 THEN
    night_plural := 'night';
  ELSE
    night_plural := 'nights';
  END IF;
  
  INSERT INTO Notifications (usernames, title, message, value, image, link, icon, color)
    SELECT ARRAY[unnest.investor], 'Apartment Booked', house_name || ' has been booked for ' || nights || ' ' || night_plural || '!', (SUM(amount) / total) * NEW.income, house_images[1], 'investment/' || NEW.house_id, 'profit', 'success'
    FROM (SELECT unnest(investors) as investor FROM houses WHERE id = NEW.house_id) as unnest
    JOIN Transactions ON unnest.investor = Transactions.source and Transactions.destination = NEW.house_id::text
    GROUP BY unnest.investor;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;