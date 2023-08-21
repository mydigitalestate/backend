CREATE OR REPLACE FUNCTION get_investment_page(h_id integer, OUT title text,
 OUT pic text[], 
 OUT location text, 
 OUT duration integer, OUT price numeric, OUT description text, OUT my_investment decimal, OUT network_investments decimal, OUT missing_investments decimal, OUT total_required decimal, OUT my_profits decimal, OUT network_profits decimal, OUT top_investors json, OUT similar_houses json, OUT is_ready boolean, OUT is_investor boolean, OUT current_ROI decimal, OUT current_ROI_percentage decimal, OUT bookings decimal, OUT total_days_passed decimal, OUT occupancy_rate decimal, OUT missing_time decimal, OUT investment_details json)
AS $$
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

        SELECT COALESCE(g.my_profits, 0) INTO current_ROI
        FROM get_total_profits(h_id, get_username(auth.uid()), start_date_val, end_date_val) g
        WHERE g.houseId = h_id;

        SELECT COUNT(*) INTO bookings
        FROM bookings
        WHERE h_id = h_id;

        SELECT DATE_PART('day', current_timestamp - h.start_date) INTO total_days_passed
        FROM houses h
        WHERE h.id = h_id;

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
            COALESCE(current_ROI, 0),
            ROUND(COALESCE((COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val), 0) / NULLIF(COALESCE(current_ROI, 1), 0)) * 100, 0), 2) AS current_ROI_percentage,
            COALESCE(bookings, 0),
            COALESCE(total_days_passed, 0),
            ROUND(COALESCE((bookings / total_days_passed) * 100, 0),2) AS occupancy_rate,
            CASE
                WHEN EXTRACT(DAY FROM (h.start_date + make_interval(months := h.duration)) - (current_timestamp - interval '1 day')) > 0
                THEN EXTRACT(DAY FROM (h.start_date + make_interval(months := h.duration)) - (current_timestamp - interval '1 day'))
                ELSE 0
            END AS missing_time,
            h.investment_details
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
            investment_details
        FROM houses h
        WHERE h.id = h_id;
    END;
END;
$$ LANGUAGE plpgsql;