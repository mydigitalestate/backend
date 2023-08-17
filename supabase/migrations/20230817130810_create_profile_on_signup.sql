CREATE OR REPLACE FUNCTION create_profile_for_new_user()
RETURNS TRIGGER AS $$

BEGIN
    -- Check if the username contains special characters
    IF NEW.raw_user_meta_data ->> 'username' ~ '[^a-zA-Z0-9]' THEN
        RAISE EXCEPTION 'Username cannot contain special characters';
    END IF;

    -- Construct the JSONB object with the lowercased username
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('username', lower(NEW.raw_user_meta_data ->> 'username'));

    -- Set default ranking and invite_limits values
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('ranking', 'Citizen', 'invite_limits', '0');

    -- Check if the inviter is 'andreafuturi'
    IF NEW.raw_user_meta_data ->> 'invited_by' = 'andreafuturi' THEN
        NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('ranking', 'Centurion', 'invite_limits', '5');
    END IF;

    -- Insert the record into the profiles table
    INSERT INTO public.profiles (id, email, username, invited_by, ranking, invite_limits)
    VALUES (
        NEW.id,
        NEW.email,
        lower(NEW.raw_user_meta_data ->> 'username'),
        NEW.raw_user_meta_data ->> 'invited_by',
        (NEW.raw_user_meta_data ->> 'ranking')::text,
        (NEW.raw_user_meta_data ->> 'invite_limits')::numeric
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


create trigger create_profile_on_signup
after insert on auth.users for each row
execute function create_profile_for_new_user ();