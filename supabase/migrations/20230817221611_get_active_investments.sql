CREATE OR REPLACE FUNCTION get_active_investments()
RETURNS SETOF houses AS $$
BEGIN
    RETURN QUERY
        SELECT * 
        FROM houses
        WHERE start_date + interval '1 month' * duration >= now() AND
              get_username(auth.uid()) = ANY(investors);
END;
$$ LANGUAGE plpgsql;
