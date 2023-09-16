CREATE OR REPLACE FUNCTION get_past_investments()
RETURNS SETOF houses AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM houses
        WHERE start_date + interval '1 month' * duration <= now();
END;
$$ LANGUAGE plpgsql;