CREATE OR REPLACE FUNCTION get_completed_properties()
RETURNS setof houses
AS $$
BEGIN
    RETURN QUERY SELECT * FROM houses WHERE amount_reached >= total_required;
END;
$$ LANGUAGE plpgsql;