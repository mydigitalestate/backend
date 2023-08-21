 CREATE OR REPLACE FUNCTION get_dashboard_page(
    OUT my_investments decimal,
    OUT investment_increase decimal,
    OUT my_profits decimal,
    OUT profits_increase decimal,
    OUT my_network integer,
    OUT network_increase decimal,
    OUT almost_completed json,
    OUT amount numeric[],
    OUT this_day_profits numeric,
    OUT new_houses json
)
AS $$
DECLARE
    this_week_investments NUMERIC;
    this_week_profit_from_houses NUMERIC;
    this_week_profit_from_network NUMERIC;
    this_week_network NUMERIC;
    end_date DATE;
    start_date DATE;
    week_start_date DATE;
    week_end_date DATE;
    booking_ids text[];
    week_days date[];
    profits_arr numeric[];
BEGIN
    end_date := CURRENT_DATE;
    start_date := end_date - INTERVAL '7 days';
    week_start_date := date_trunc('week', end_date)::date;
    week_end_date := (date_trunc('week', end_date) + '6 days')::date;

    BEGIN
        SELECT COALESCE(get_total_investments(get_username(auth.uid()), week_start_date, week_end_date), 0) INTO this_week_investments;
        SELECT COALESCE(SUM(profit), 0) INTO this_week_profit_from_houses
        FROM get_profits_for_every_house(get_username(auth.uid()), week_start_date, week_end_date);
        SELECT COALESCE(SUM(profits), 0) INTO this_week_profit_from_network
        FROM get_profits_from_each_user_network(week_start_date, week_end_date, get_username(auth.uid()));
        SELECT COUNT(*) FROM get_network(get_username(auth.uid()), week_start_date, week_end_date) INTO this_week_network;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            this_week_investments := 0;
            this_week_profit_from_houses := 0;
            this_week_profit_from_network := 0;
            this_week_network := 0;
    END;

    investment_increase := this_week_investments;
    profits_increase := (this_week_profit_from_houses + this_week_profit_from_network);
    network_increase := this_week_network;

    BEGIN
        SELECT
            p.total_investments AS my_investments,
            p.total_profits AS my_profits,
            (SELECT COUNT(*) FROM get_network(get_username(auth.uid()), '1900-02-08', '2900-02-08') AS my_network)
        INTO STRICT
            my_investments,
            my_profits,
            my_network
        FROM
            profiles p
        WHERE
            p.username = get_username(auth.uid())
        GROUP BY
            p.total_profits,
            p.total_investments;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            my_investments := 0;
            my_profits := 0;
            my_network := 0;
    END;

    SELECT json_agg(t) INTO almost_completed
    FROM (
        SELECT * FROM get_almost_completed()
    ) t;

    SELECT array_agg(id::text) INTO booking_ids
    FROM bookings;

   -- Create a temporary table to store the results
CREATE TEMP TABLE temp_results (weekday date, total_amount numeric);

-- Generate the array of weekdays
week_days := ARRAY(SELECT generate_series(week_start_date, week_end_date, '1 day'::interval)::date);

-- Populate the temporary table with the results
INSERT INTO temp_results (weekday, total_amount)
SELECT
    week_days[i] AS weekday,
    COALESCE(SUM(transactions.amount), 0) AS total_amount
FROM
    generate_subscripts(week_days, 1) AS i
LEFT JOIN
    transactions ON transactions.destination = get_username(auth.uid())
                  AND transactions.timestamp::date = week_days[i]
GROUP BY
    week_days[i]
ORDER BY
    week_days[i];

-- Fetch the results into the amount array
SELECT array_agg(total_amount) INTO amount FROM temp_results;

-- Drop the temporary table
DROP TABLE temp_results;



    this_day_profits := (
        SELECT COALESCE(SUM(transactions.amount), 0)
        FROM transactions
        -- JOIN bookings ON bookings.id::text = transactions.source
        WHERE transactions.destination = get_username(auth.uid())
            AND transactions.timestamp::date = CURRENT_DATE
            -- AND bookings.id::text = ANY (booking_ids)
        GROUP BY transactions.timestamp::date
    );

    SELECT json_agg(t) INTO new_houses
    FROM (
        SELECT * FROM get_new_houses()
    ) t;



 my_investments := my_investments;
    investment_increase := investment_increase;
    my_profits := my_profits;
    profits_increase := profits_increase;
    my_network := my_network;
    network_increase := network_increase;
    almost_completed := almost_completed;
    amount := amount;
    this_day_profits := this_day_profits;
    new_houses := new_houses;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_dashboard_page();
