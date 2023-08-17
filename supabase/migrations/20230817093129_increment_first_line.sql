CREATE OR REPLACE FUNCTION increment_first_line()
RETURNS TRIGGER AS $$


BEGIN
    UPDATE public.profiles SET first_line = first_line + 1 WHERE username = NEW.invited_by;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;