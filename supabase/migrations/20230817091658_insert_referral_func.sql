CREATE OR REPLACE FUNCTION insert_referral_func()
RETURNS TRIGGER AS $$

BEGIN
  INSERT INTO public.referrals (username, invited_by)
  VALUES (NEW.username, NEW.invited_by);
  RETURN NULL;
END;

$$ LANGUAGE plpgsql;