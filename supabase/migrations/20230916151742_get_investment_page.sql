CREATE
OR REPLACE FUNCTION get_investment_page(
  h_id integer,
  OUT title text,
  OUT pic text[],
  OUT location text,
  OUT duration integer,
  OUT price numeric,
  OUT description text,
  OUT my_investment numeric,
  OUT network_investments numeric,
  OUT missing_investments numeric,
  OUT total_required decimal,
  OUT my_profits numeric,
  OUT network_profits numeric,
  OUT top_investors json,
  OUT similar_houses json,
  OUT is_ready boolean,
  OUT is_investor boolean,
  OUT current_ROI decimal,
  OUT current_ROI_percentage numeric,
  OUT bookings decimal,
  OUT total_days_passed decimal,
  OUT occupancy_rate decimal,
  OUT missing_time decimal,
  OUT investment_details json,
  OUT daily_investment_cost decimal,
  OUT investment_used_now decimal, 
  OUT total_contract_days decimal

) AS $$

DECLARE
    start_date_val DATE;
    end_date_val DATE;
BEGIN
    start_date_val := '1900-01-01';
    end_date_val := '2900-01-01';

    BEGIN

        SELECT COALESCE(g.my_profits,0)g INTO my_profits
        FROM get_total_profits(h_id, get_username(auth.uid()), start_date_val, end_date_val)g
        WHERE g.houseId = h_id;

        SELECT COALESCE(g.network_profits,0)g INTO network_profits
        FROM get_total_profits(h_id, get_username(auth.uid()), start_date_val, end_date_val)g
        WHERE g.houseId = h_id;

        SELECT json_agg(t) INTO top_investors
        FROM (
            SELECT *
            FROM get_top_investors(h_id,start_date_val, end_date_val)LIMIT 6
        ) t;

        SELECT json_agg(t) INTO similar_houses
        FROM (
            SELECT *
            FROM get_similar_houses(h_id)
        ) t;

SELECT 
    CASE
        WHEN h.start_date IS NOT NULL THEN
            GREATEST(
                1,
                CASE
                    WHEN (h.start_date + (h.duration || ' months')::interval) < current_timestamp THEN
                        CAST(EXTRACT(EPOCH FROM (h.start_date + (h.duration || ' months')::interval - h.start_date)) / 86400 AS INTEGER)
                    ELSE
                        CAST(EXTRACT(EPOCH FROM (current_timestamp - h.start_date)) / 86400 AS INTEGER)
                END
            )
        ELSE 0
    END
INTO total_days_passed
FROM houses h
WHERE h.id = h_id;

SELECT
    COALESCE(get_total_investments(h.id, get_username(auth.uid()) , start_date_val, end_date_val), 0) / CAST(EXTRACT(EPOCH FROM (h.start_date + (h.duration || ' months')::interval - h.start_date)) / 86400 AS INTEGER) INTO daily_investment_cost
FROM
    houses h
    WHERE h.id = h_id;



investment_used_now = daily_investment_cost * total_days_passed;
 
SELECT 
  DATE_PART('day', (h.start_date + (h.duration || ' months')::interval)::date - h.start_date) INTO total_contract_days
FROM
  houses h
WHERE 
  h.id = h_id;


        SELECT 
            h.name AS title, 
            h.images AS pic, 
            h.address AS location,
            h.duration AS duration,
            h.price AS price,
            h.description AS description,
            COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val),0) AS my_investment,
            h.amount_reached-COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val),0) AS network_investments,
            GREATEST(0, h.total_required - h.amount_reached) AS missing_investments,
            h.total_required AS total_required,
            COALESCE(my_profits, 0),
            COALESCE(network_profits, 0),
            COALESCE(top_investors, '[]'::json),
            COALESCE(similar_houses, '[]'::json),
            h.is_ready,
            EXISTS (
                SELECT 1
                FROM unnest(h.investors) AS investor_name
                WHERE investor_name = get_username(auth.uid())
            ) AS is_investor,
            COALESCE(my_profits, 0) AS current_ROI,
        COALESCE(
    ROUND(
        (((my_profits - COALESCE(investment_used_now, 0)) / NULLIF(investment_used_now, 0)) * 100),
        2
    ),
    0
) AS current_ROI_percentage,

            COALESCE(get_booked_days(h_id) , 0) AS bookings,
            COALESCE(total_days_passed, 0),
ROUND(
    CASE
        WHEN COALESCE(total_contract_days, 0) <> 0
            THEN COALESCE(get_booked_days(h_id), 0) / COALESCE(total_contract_days, 0) * 100
        ELSE 0
    END,
    2
) AS occupancy_rate,
            CASE
                WHEN EXTRACT(DAY FROM (h.start_date + make_interval(months := h.duration)) - (current_timestamp - interval '1 day')) > 0
                THEN EXTRACT(DAY FROM (h.start_date + make_interval(months := h.duration)) - (current_timestamp - interval '1 day'))
                ELSE 0
            END AS missing_time,
            h.investment_details,
            COALESCE(ROUND(daily_investment_cost,2), 0),
            COALESCE(ROUND(investment_used_now,2), 0),
            COALESCE(total_contract_days, 0)
        INTO
            title,
            pic,
            location,
            duration,
            price,
            description,
            my_investment,
            network_investments,
            missing_investments,
            total_required,
            my_profits,
            network_profits,
            top_investors,
            similar_houses,
            is_ready,
            is_investor,
            current_ROI,
            current_ROI_percentage,
            bookings,
            total_days_passed,
            occupancy_rate,
            missing_time,
            investment_details,
            daily_investment_cost,
            investment_used_now,
            total_contract_days
        FROM houses h
        WHERE h.id = h_id;
    END;
END;
$$ LANGUAGE plpgsql;
