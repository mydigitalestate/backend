CREATE OR REPLACE FUNCTION create_new_citizen_notification()
RETURNS TRIGGER AS $$

BEGIN
  INSERT INTO public.notifications (usernames, title, message, image, link, icon)
  VALUES ( ARRAY[NEW.invited_by::text], 'New Citizen In The Network',
    CONCAT(INITCAP(NEW.username)) || ' subscribed thanks to you!', public.get_avatar(NEW.username),NEW.username, 'network');
  RETURN NEW;
END;


$$ LANGUAGE plpgsql;