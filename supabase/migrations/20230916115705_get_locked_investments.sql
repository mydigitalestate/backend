CREATE OR REPLACE FUNCTION get_locked_investments()
RETURNS SETOF houses AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM houses
        WHERE amount_reached < total_required
        AND get_username(auth.uid()) = ANY(investors);
END;
$$ LANGUAGE plpgsql;
