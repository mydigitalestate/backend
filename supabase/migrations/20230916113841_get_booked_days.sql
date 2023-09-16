CREATE OR REPLACE FUNCTION get_booked_days(houseid INT)
RETURNS INT AS $$
DECLARE
    booked_days INT;
BEGIN
    -- Calculate the number of booked days in the past
    SELECT COALESCE(SUM(b.end_date::DATE - b.start_date::DATE))
            -- CASE
            --     WHEN (b.start_date::DATE <= CURRENT_DATE AND b.end_date::DATE >= h.start_date::DATE) THEN
            --         LEAST(b.end_date::DATE, CURRENT_DATE) - GREATEST(h.start_date::DATE, b.start_date::DATE)
            --     ELSE 0
            -- END), 0)
    INTO booked_days
    FROM bookings b
    JOIN houses h ON b.house_id = h.id
    WHERE b.house_id = houseid;

    RETURN booked_days;
END;
$$ LANGUAGE plpgsql;