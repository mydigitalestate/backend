CREATE OR REPLACE FUNCTION get_profile_page(profile_username text, OUT avatar text, OUT display_name text, OUT public_profile boolean, OUT top_investments json, OUT networker_table json, OUT last_investments json, OUT usernames text[], OUT ranking text, OUT days_since_signup integer)
AS $$
DECLARE
    end_date DATE;
    start_date DATE;
BEGIN
    end_date := '2900-01-01';
    start_date := '1900-01-01';

    SELECT 
        get_avatar(p.username) as avatar,
        INITCAP(p.display_name), p.public_profile, p.ranking
    INTO avatar, display_name, public_profile, ranking 
    FROM profiles_view p
    WHERE p.username = profile_username
    GROUP BY p.username, p.display_name, p.public_profile, p.ranking;

    SELECT array_agg(p.username) INTO usernames
    FROM profiles_view p;

    SELECT COALESCE(json_agg(t), '[]'::json) INTO top_investments
    FROM (SELECT * FROM get_top_investments(profile_username) LIMIT 3) t; 

    SELECT COALESCE(json_agg(t), '[]'::json) INTO networker_table
    FROM (SELECT * FROM get_networker_table(profile_username) LIMIT 8) t;   
    
    SELECT COALESCE(json_agg(t), '[]'::json) INTO last_investments
    FROM (SELECT * FROM get_last_investments(profile_username, start_date, end_date) LIMIT 10) t;

    SELECT EXTRACT(DAY FROM NOW() - r.subscribed_at) INTO days_since_signup
    FROM referrals r
    WHERE r.username = profile_username;

END;
$$ LANGUAGE plpgsql;