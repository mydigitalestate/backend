CREATE OR REPLACE FUNCTION get_new_houses()
RETURNS TABLE (
    house_id INT,
    name TEXT,
    duration INT,
    address TEXT,
    price NUMERIC,
    pic TEXT
) AS $$
BEGIN
    RETURN QUERY SELECT h.id, h.name, h.duration, h.address, h.price, h.images[1]
                  FROM houses h
                  WHERE (h.publishing_date BETWEEN now() - interval '30 days' AND now()) AND h.amount_reached < h.total_required;

END;
$$ LANGUAGE plpgsql;