CREATE OR REPLACE FUNCTION get_similar_houses(houseid integer)
RETURNS TABLE (
  house_id integer,
  title text,
  pic text,
  location text,
  duration integer,
  house_price numeric,
  total_required numeric,
  personal_invested_amount numeric,
  amount_reached int4
  ) AS $$
BEGIN
    RETURN QUERY
    SELECT
        h.id AS house_id,
        h.name AS title,
        h.images[1] AS pic,
        h.address AS location,
        h.duration AS duration,
        h.price AS house_price,
        h.total_required AS total_required,
        COALESCE(get_total_investments(h.id, get_username(auth.uid()), '1900-01-01', '2900-01-01'), 0) AS personal_invested_amount,
        h.amount_reached AS amount_reached
    FROM houses h
    WHERE h.id != houseid AND h.amount_reached < h.total_required
    ORDER BY random();
END;
$$ LANGUAGE plpgsql;