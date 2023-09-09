CREATE OR REPLACE FUNCTION notiffications_promote_trigger()
RETURNS TRIGGER AS $$
DECLARE
  second_line_inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);

  begin
    perform private.promote_notiffications(NEW.id);
    return NULL;
  end;
  

$$ LANGUAGE plpgsql;