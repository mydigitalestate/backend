CREATE OR REPLACE FUNCTION create_referral_transaction()
RETURNS TRIGGER AS $$

DECLARE
  inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
  second_line_inviter_username VARCHAR(255);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    IF NEW.amount > 0 THEN 
    -- First-line referral
    SELECT invited_by INTO inviter_username FROM Referrals WHERE username = NEW.source;
    IF inviter_username IS NOT NULL THEN
      SELECT first_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = inviter_username);
      referral_amount := (NEW.amount * referral_amount) / 100;
        IF referral_amount >= 0.01 THEN
        INSERT INTO Transactions (source, destination, amount) 
        VALUES (NEW.source, inviter_username ,referral_amount);
      END IF;
    END IF;

    -- Second-line referral
    SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM Referrals WHERE username = NEW.source);
    IF second_line_inviter_username IS NOT NULL THEN
      SELECT second_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM Profiles WHERE username = second_line_inviter_username);
      referral_amount := (NEW.amount * referral_amount) / 100;
        IF referral_amount >= 0.01 THEN
        INSERT INTO Transactions (source, destination, amount) 
        VALUES (NEW.source, second_line_inviter_username , referral_amount);
      END IF;
    END IF;
  END IF;
END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;