CREATE OR REPLACE FUNCTION delete_referral_func()
RETURNS TRIGGER AS $$

BEGIN
  DELETE FROM public.referrals
  WHERE username = OLD.username;
  RETURN NULL;
END;

$$ LANGUAGE plpgsql;