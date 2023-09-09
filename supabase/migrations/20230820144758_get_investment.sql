CREATE OR REPLACE FUNCTION get_investment(
    uid uuid,
    start_date_val date DEFAULT '1900-02-08'::date,
    end_date_val date DEFAULT '2900-02-08'::date
)
RETURNS numeric AS $$
DECLARE
    total_investment numeric;
BEGIN
    WITH RECURSIVE referrals_res(username, invited_by, subscribed_at) AS (
        SELECT username, invited_by, subscribed_at FROM public.referrals WHERE username = get_username(uid)
        UNION ALL
        SELECT u.username, u.invited_by, r.subscribed_at FROM referrals r, referrals u 
        WHERE r.username = u.invited_by AND r.subscribed_at BETWEEN start_date_val AND end_date_val
    )
    SELECT SUM(get_total_investments(username, start_date_val, end_date_val)) INTO total_investment
    FROM referrals_res WHERE username ='tiberius';
    
    RETURN total_investment;
END;
$$ LANGUAGE plpgsql;
