CREATE OR REPLACE FUNCTION get_profits_page(
    OUT total_properties_profits decimal,
    OUT six_month_contract_profit decimal,
    OUT twelve_month_contract_profit decimal,
    OUT life_time_contract_profit decimal,
    OUT total_bookings decimal,
    OUT six_month_contract_booking decimal,
    OUT twelve_month_contract_booking decimal,
    OUT life_time_contract_booking decimal,
    OUT total_network_profits decimal,
    OUT first_line_profits decimal,
    OUT second_line_profits decimal,
    OUT other_lines_profits decimal,
    OUT total_network decimal,
    OUT first_line_network decimal,
    OUT second_line_network decimal,
    OUT other_lines_network decimal,
    OUT my_properties json,
    OUT my_network json,
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
        SELECT COALESCE(SUM(profit), 0)
        INTO six_month_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration = 6;
        SELECT COALESCE(SUM(profit), 0)
        INTO twelve_month_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration = 12;
        SELECT COALESCE(SUM(profit), 0)
        INTO life_time_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration IS NULL;

        total_properties_profits := six_month_contract_profit + twelve_month_contract_profit + life_time_contract_profit;

        -- SELECT p.total_profits
        -- INTO total_properties_profits
        -- FROM profiles p
        -- WHERE p.username=get_username(auth.uid());

       SELECT COALESCE(COUNT(*), 0) INTO six_month_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration = 6 AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;

       SELECT COALESCE(COUNT(*), 0) INTO twelve_month_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration = 12 AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;

       SELECT COALESCE(COUNT(*), 0) INTO life_time_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration IS NULL AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;       

        total_bookings := six_month_contract_booking + twelve_month_contract_booking + life_time_contract_booking;

        SELECT COALESCE(SUM(profits), 0)
        INTO first_line_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 1;
        SELECT COALESCE(SUM(profits), 0)
        INTO second_line_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 2;
        SELECT COALESCE(SUM(profits), 0)
        INTO other_lines_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level > 2;

        total_network_profits := first_line_profits + second_line_profits + other_lines_profits;

        SELECT COALESCE(COUNT(*), 0)
        INTO first_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 1;
        SELECT COALESCE(COUNT(*), 0)
        INTO second_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 2;
        SELECT COALESCE(COUNT(*), 0)
        INTO other_lines_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level > 2;

        total_network := first_line_network + second_line_network + other_lines_network;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            six_month_contract_profit := 0;
            twelve_month_contract_profit := 0;
            life_time_contract_profit := 0;
            total_properties_profits := 0;
            six_month_contract_booking := 0;
            twelve_month_contract_booking := 0;
            life_time_contract_booking := 0;
            total_bookings := 0;
            first_line_profits := 0;
            second_line_profits := 0;
            other_lines_profits := 0;
            total_network_profits := 0;
            first_line_network := 0;
            second_line_network := 0;
            other_lines_network := 0;
            total_network := 0;
    END;

    SELECT json_agg(t) INTO my_properties
    FROM (
        SELECT * FROM get_properties(start_date, end_date)
    ) t;

    SELECT COALESCE(json_agg(k), '[]'::json) INTO my_network
    FROM (
        SELECT * FROM get_network_table()
    ) k;

    amounts := ARRAY(
        SELECT COALESCE(SUM(amount), 0) 
        FROM (
            SELECT DISTINCT m AS month
            FROM generate_series(1, 12) AS m
        ) months
        LEFT JOIN transactions ON transactions.source IS NOT NULL
            AND transactions.destination = get_username(auth.uid())
            AND transactions.timestamp BETWEEN make_date(year_val, months.month, 1)
            AND (make_date(year_val, months.month, 1) + interval '1 month' - interval '1 day')
        GROUP BY months.month
        ORDER BY months.month
    );

    RETURN;

END;
$$ LANGUAGE plpgsql;