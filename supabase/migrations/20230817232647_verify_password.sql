CREATE OR REPLACE FUNCTION verify_password(entered_password text, stored_hash text)
RETURNS boolean AS $$
BEGIN
  -- Compare the hashed entered_password with the stored_hash
  RETURN crypt(entered_password, stored_hash) = stored_hash;
END;
$$ LANGUAGE plpgsql;
