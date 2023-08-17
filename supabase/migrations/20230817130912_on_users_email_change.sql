CREATE OR REPLACE FUNCTION update_profiles_email()
RETURNS TRIGGER AS $$


BEGIN
  IF NEW.email <> OLD.email THEN
    UPDATE profiles
    SET email = NEW.email
     WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;

create trigger on_users_email_change
after
update of email on auth.users for each row
execute function update_profiles_email ();