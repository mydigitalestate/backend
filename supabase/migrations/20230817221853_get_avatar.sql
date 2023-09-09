CREATE OR REPLACE FUNCTION get_avatar(user_name text)
RETURNS TEXT AS
$$
DECLARE
    avatar_filename TEXT;
BEGIN
    -- Check if the avatar exists in Supabase storage for the given username
    SELECT name
    INTO avatar_filename
     FROM storage.objects
      WHERE  bucket_id= 'avatar' AND name = user_name
    LIMIT 1;

    -- If an avatar exists, return the filename; otherwise, return ranking
    IF avatar_filename IS NULL THEN
        SELECT ranking
        INTO avatar_filename
        FROM public.profiles_view
        WHERE username = user_name;
    END IF;

    RETURN avatar_filename;
END;
$$
LANGUAGE plpgsql;