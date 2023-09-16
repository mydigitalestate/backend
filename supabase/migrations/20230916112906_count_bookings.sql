CREATE OR REPLACE FUNCTION count_bookings(
    house_id_param integer,
    start_date_param date,
    end_date_param date
) RETURNS integer AS $$
BEGIN
    RETURN (
        SELECT COUNT(house_id)
        FROM bookings
        WHERE house_id = house_id_param
        AND start_date BETWEEN start_date_param AND end_date_param
        AND end_date BETWEEN start_date_param AND end_date_param
    );
END;
$$ LANGUAGE plpgsql;
