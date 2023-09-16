CREATE
OR REPLACE FUNCTION get_network_page (
  OUT total_network decimal,
  OUT first_line_network decimal,
  OUT second_line_network decimal,
  OUT other_line_network decimal,
  OUT total_investments decimal,
  OUT first_line_investments decimal,
  OUT second_line_investments decimal,
  OUT other_line_investments decimal,
  OUT my_network json,
  OUT amount numeric[],
  OUT limits_left integer,
  OUT referral_profit_rate integer
) AS $$
DECLARE
    end_date DATE;
    start_date DATE;
    invite_limit integer;  
    invite_number integer;  

BEGIN
    start_date := '1900-01-01';
    end_date := '2900-01-01';

 SELECT invite_limits INTO invite_limit
    FROM profiles
    WHERE username = get_username(auth.uid());

    BEGIN
        SELECT COALESCE(COUNT(*), 0) INTO first_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 1;

        SELECT COALESCE(COUNT(*), 0) INTO second_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 2;

        SELECT COALESCE(COUNT(*), 0) INTO other_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level > 2;

        total_network := COALESCE(first_line_network, 0) + COALESCE(second_line_network, 0) + COALESCE(other_line_network, 0);

          SELECT COALESCE(SUM(get_total_investments(username, start_date, end_date)), 0) INTO first_line_investments
FROM (
  SELECT r.username, r.invited_by, ru.level, ru.subscribed_at
  FROM public.referrals r
  JOIN get_network(get_username(auth.uid()), start_date, end_date) ru
  ON r.username = ru.username
) AS network
WHERE network.level = 1;

           SELECT COALESCE(SUM(get_total_investments(username, start_date, end_date)), 0) INTO second_line_investments
FROM (
  SELECT r.username, r.invited_by, ru.level, ru.subscribed_at
  FROM public.referrals r
  JOIN get_network(get_username(auth.uid()), start_date, end_date) ru
  ON r.username = ru.username
) AS network
WHERE network.level = 2;
      

       
          SELECT COALESCE(SUM(get_total_investments(username, start_date, end_date)), 0) INTO other_line_investments
FROM (
  SELECT r.username, r.invited_by, ru.level, ru.subscribed_at
  FROM public.referrals r
  JOIN get_network(get_username(auth.uid()), start_date, end_date) ru
  ON r.username = ru.username
) AS network
WHERE network.level > 2;

        total_investments := COALESCE(first_line_investments, 0) + COALESCE(second_line_investments, 0) + COALESCE(other_line_investments, 0);
 
        SELECT COALESCE(COUNT(*), 0) INTO invite_number
        FROM referrals
        WHERE invited_by =  get_username(auth.uid());
        limits_left := CASE WHEN invite_limit - invite_number >= 0 THEN invite_limit - invite_number ELSE 0 END;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            first_line_network := 0;
            second_line_network := 0;
            other_line_network := 0;
            total_network := 0;
            first_line_investments := 0;
            second_line_investments := 0;
            other_line_investments := 0;
            total_investments := 0;
    END;

    SELECT COALESCE(json_agg(k), '[]'::json) INTO my_network
    FROM (
        SELECT *
        FROM get_networker_table(get_username(auth.uid()))
    ) k;

    SELECT ARRAY_AGG(COALESCE(t.amount, 0) ORDER BY am.month) INTO amount
    FROM (
        SELECT generate_series(
            '2023-01-01'::date,
            '2023-12-01'::date,
            '1 month'::interval
        ) AS month
    ) am
    LEFT JOIN (
        SELECT date_trunc('month', i.timestamp) AS month, SUM(i.amount) AS amount
        FROM transactions i
        WHERE i.source IN (SELECT username FROM get_network(get_username(auth.uid()), start_date, end_date))
            AND i.destination ~ '^\d+$'
        GROUP BY date_trunc('month', i.timestamp)
    ) t ON am.month = t.month;


SELECT
    r.first_line_rate INTO referral_profit_rate
FROM
    profiles p
JOIN
    ranking r ON p.ranking = r.name
WHERE
    p.username = get_username(auth.uid());

    RETURN;

END;
$$ LANGUAGE plpgsql;

SELECT
  *
FROM
  get_network_page ();
