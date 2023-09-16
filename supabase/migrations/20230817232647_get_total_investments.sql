CREATE OR REPLACE FUNCTION get_total_investments( 
    user_name TEXT DEFAULT get_username(auth.uid()),
    start_date_val DATE DEFAULT '1900-02-08'::date, 
    end_date_val DATE DEFAULT '2900-02-08'::date)
RETURNS NUMERIC AS $$
DECLARE
    total NUMERIC;
BEGIN
    SELECT SUM(amount) INTO total
    FROM transactions
    WHERE source = user_name
    AND destination ~ '^\d+$'
    AND timestamp >= start_date_val
    AND timestamp <= end_date_val + INTERVAL '1 day'; --added this because the the end_date_val was not included and the result was wrong
    
    RETURN total;
END;
$$ LANGUAGE plpgsql;