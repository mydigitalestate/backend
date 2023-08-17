CREATE OR REPLACE FUNCTION notify_rank_change_network()
RETURNS TRIGGER AS $$

BEGIN
  IF OLD.ranking != NEW.ranking THEN
    INSERT INTO Notifications(usernames, title, message, image, link,icon,platform)
    VALUES (
      (SELECT array_agg(username) FROM Referrals WHERE username = NEW.invited_by OR invited_by = NEW.username),
      'New '||NEW.ranking||' In The Network',
        COALESCE( INITCAP(NEW.display_name), INITCAP(NEW.username))||' turned into a '||NEW.ranking||'!',
      public.get_avatar(NEW.username), NEW.username,'level',ARRAY['in-app']
    );
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;