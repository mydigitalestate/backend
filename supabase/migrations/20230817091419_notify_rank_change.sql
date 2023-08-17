CREATE OR REPLACE FUNCTION notify_rank_change()
RETURNS TRIGGER AS $$

BEGIN
    IF NEW.ranking != OLD.ranking THEN
        INSERT INTO Notifications (usernames, title, message,link, icon,image)
        VALUES (ARRAY[NEW.username], 'Level Up!', 'Congratulations you turned into a ' || NEW.ranking || '!' , NEW.username, 'upgrade',public.get_avatar(NEW.username));
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;