CREATE OR REPLACE FUNCTION get_settings_page(
    OUT username text,
    OUT display_name text,
    OUT email text,
    OUT phone text,
    OUT email_change varchar,
    OUT confirmed_email varchar,
    OUT wallet_data json,
    OUT profile_public boolean
)
AS $$
BEGIN
    SELECT 
        p.username AS username,
        p.display_name AS display_name, 
        p.email AS email,
        u.phone AS phone,
        u.email_change::varchar AS email_change,
        u.email AS confirmed_email, 
        COALESCE((
            SELECT json_agg(json_build_object('name', w.wallet_name, 'address', w.address, 'verified', w.is_verified))
            FROM wallets w
            WHERE p.username = w.owned_by
              AND w.wallet_name IS NOT NULL
        ), '[]'::json) AS wallet_data,
        p.public_profile AS profile_public
    INTO
        username,
        display_name,
        email,
        phone,
        email_change,
        confirmed_email,
        wallet_data,
        profile_public
    FROM 
        profiles p 
    LEFT JOIN auth.users u ON p.id = u.id AND p.username = get_username(auth.uid())
    WHERE 
        p.username = get_username(auth.uid());

    IF NOT FOUND THEN
        username := NULL;
        display_name := NULL;
        email := NULL;
        phone := NULL;
        email_change := NULL;
        confirmed_email := NULL;
        wallet_data := '[]'::json;
        profile_public := false;
    END IF;
END;
$$ LANGUAGE plpgsql;