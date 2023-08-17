CREATE OR REPLACE FUNCTION create_referral_notification()
RETURNS TRIGGER AS $$

DECLARE
  inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
  second_line_inviter_username VARCHAR(255);
  house_name VARCHAR(255);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    -- first line inviter
    SELECT invited_by INTO inviter_username FROM public.referrals WHERE username = NEW.source;
    
    IF inviter_username IS NOT NULL THEN
      SELECT first_line_rate INTO referral_amount FROM public.ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = inviter_username);
      SELECT name INTO house_name FROM public.houses WHERE id::text = NEW.destination;
      referral_amount := (NEW.amount * referral_amount) / 100;

      IF referral_amount > 0 THEN 
      INSERT INTO public.notifications (title, message, usernames, value, image, link,color)
      VALUES ('New Investment In The Network', 
              CONCAT(COALESCE((SELECT INITCAP(display_name) FROM public.profiles WHERE username = NEW.source), INITCAP(NEW.source)), ' invested ', NEW.amount, ' USDT on ', house_name, '!'),
              ARRAY[inviter_username], referral_amount , public.get_avatar(NEW.source), 'profits/?network=true','success');
    END IF;
END IF;
    -- second line inviter
    SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.source);
    IF second_line_inviter_username IS NOT NULL THEN
      SELECT second_line_rate INTO referral_amount FROM public.ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = second_line_inviter_username);
      referral_amount := (NEW.amount * referral_amount) / 100;

      IF referral_amount > 0 THEN 
      INSERT INTO public.notifications (title, message, usernames, value, image, link,color)
      VALUES ('New Investment In The Network', 
              CONCAT(COALESCE((SELECT INITCAP(display_name) FROM public.profiles WHERE username = NEW.source), INITCAP(NEW.source)), ' invested ', NEW.amount, ' USDT on ', house_name, '!'),
              ARRAY[second_line_inviter_username], referral_amount, public.get_avatar(NEW.source), 'profits/?network=true','success');
    END IF;
    END IF;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;