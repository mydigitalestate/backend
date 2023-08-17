CREATE OR REPLACE FUNCTION create_third_line_referral_transaction()
RETURNS TRIGGER AS $$
DECLARE
  second_line_inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    IF EXISTS (SELECT 1 FROM Referrals WHERE username = NEW.source) THEN
      SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM Referrals WHERE username = NEW.source);
      IF second_line_inviter_username IS NOT NULL THEN
        SELECT second_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM Profiles WHERE username = second_line_inviter_username);
        referral_amount := (NEW.amount * referral_amount) / 100;
        INSERT INTO Transactions (source, destination, amount, timestamp) 
        VALUES (NEW.source, second_line_inviter_username , referral_amount, NOW());
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;