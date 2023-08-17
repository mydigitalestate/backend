CREATE OR REPLACE FUNCTION increment_third_line()
RETURNS TRIGGER AS $$

BEGIN
    UPDATE public.profiles SET third_line = third_line + 1 WHERE username = (SELECT invited_by FROM public.referrals WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.invited_by));
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;