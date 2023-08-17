CREATE OR REPLACE FUNCTION limit_inviter()
RETURNS TRIGGER AS $$
DECLARE
  invite_limit INT;
BEGIN


  SELECT invite_limits INTO invite_limit
  FROM public.profiles
  WHERE username = NEW.invited_by;
  
  IF invite_limit IS NOT NULL AND (
      SELECT COUNT(*) FROM public.referrals WHERE invited_by = NEW.invited_by
    ) >= invite_limit
  THEN
    RAISE EXCEPTION '% has sent out too many invites', NEW.invited_by;
  END IF;

  RETURN NEW;
END;

$$ LANGUAGE plpgsql;