CREATE OR REPLACE FUNCTION update_user_password(user_id uuid, new_password text)
RETURNS void AS $$
BEGIN
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;
