CREATE OR REPLACE FUNCTION get_investments_page(
  OUT total_investments decimal,
  OUT active_investments decimal,
  OUT locked_investments decimal,
  OUT completed_investments decimal,
  OUT total_properties decimal,
  OUT active_properties decimal,
  OUT locked_properties decimal,
  OUT completed_properties decimal,
  OUT my_properties json,
  OUT amounts numeric[]
)
AS $$
DECLARE
    end_date DATE;
    start_date DATE;
    month_val INT;
    year_val INT;
    i INT;
BEGIN
    end_date := '2900-01-01';
    start_date := '1900-01-01';
    month_val := EXTRACT(MONTH FROM CURRENT_DATE);
    year_val := EXTRACT(YEAR FROM CURRENT_DATE);
    i := 0;

    BEGIN
   WITH active_house_id AS (
  SELECT id FROM get_active_investments()
)
SELECT COALESCE(SUM(t.amount), 0) INTO active_investments 
FROM transactions t
JOIN active_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());

    WITH locked_house_id AS (
  SELECT id FROM get_locked_investments()
)
SELECT COALESCE(SUM(t.amount), 0) INTO locked_investments 
FROM transactions t
JOIN locked_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());

   WITH completed_house_id AS (
  SELECT id FROM get_completed_properties()
)
SELECT COALESCE(SUM(t.amount), 0) INTO completed_investments 
FROM transactions t
JOIN completed_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());


        -- total_investments := active_investments + locked_investments + completed_investments;
        SELECT COALESCE(p.total_investments, 0) FROM profiles p INTO total_investments
         WHERE
            p.username = get_username(auth.uid())
        GROUP BY
            p.total_investments;

        SELECT COUNT(*) INTO active_properties FROM get_active_investments();
        SELECT COUNT(*) INTO locked_properties FROM get_locked_investments();
        SELECT COUNT(*) INTO completed_properties FROM get_completed_properties();
        total_properties := active_properties + locked_properties + completed_properties;

    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            active_investments := 0;
            locked_investments := 0;
            completed_investments := 0;
            total_investments := 0;
            active_properties := 0;
            locked_properties := 0;
            completed_properties := 0;
            total_properties := 0;
    END;

    SELECT json_agg(t) INTO my_properties
    FROM (
        SELECT * FROM get_properties(start_date, end_date)
    ) t;

    amounts := ARRAY(
        SELECT COALESCE(SUM(amount), 0)
        FROM (
            SELECT DISTINCT m AS month
            FROM generate_series(1, 12) AS m
        ) months
        LEFT JOIN transactions ON transactions.source = get_username(auth.uid())
            AND transactions.destination ~ '^\d+$'
            AND transactions.timestamp BETWEEN make_date(year_val, months.month, 1)
                AND (make_date(year_val, months.month, 1) + interval '1 month' - interval '1 day')
        GROUP BY months.month
        ORDER BY months.month
    );

END;
$$ LANGUAGE plpgsql;