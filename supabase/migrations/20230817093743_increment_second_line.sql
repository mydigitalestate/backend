CREATE OR REPLACE FUNCTION increment_second_line()
RETURNS TRIGGER AS $$

BEGIN
    UPDATE public.profiles SET second_line = second_line + 1 WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.invited_by);
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;