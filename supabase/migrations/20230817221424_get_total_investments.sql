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
            AND timestamp BETWEEN start_date_val AND end_date_val;
            RETURN total;
END;
$$ LANGUAGE plpgsql;
