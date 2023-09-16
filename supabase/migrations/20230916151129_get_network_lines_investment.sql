CREATE OR REPLACE FUNCTION get_network_lines_investment()
RETURNS TABLE("1st line" numeric, "2nd line" numeric, "3rd line" numeric) AS $$
DECLARE
  total_first_line NUMERIC := 0;
  total_second_line NUMERIC := 0;
  total_third_line NUMERIC := 0;
BEGIN
  WITH RECURSIVE referred_users(username, invited_by, level) AS (
    SELECT username, invited_by, 1
    FROM public.referrals
    WHERE invited_by = 'tiberius' AND subscribed_at BETWEEN '1900-02-08' AND '2900-02-08'
    UNION
    SELECT r.username, r.invited_by, ru.level + 1
    FROM referred_users ru
    JOIN public.referrals r ON r.invited_by = ru.username
  )
  SELECT 
    CASE 
      WHEN level = 1 THEN  COALESCE(SUM(get_total_investments(username, '1900-02-08', '2900-02-08')), 0)
      ELSE 0 
    END AS "1st line",
    CASE 
      WHEN level = 2 THEN  COALESCE(SUM(get_total_investments(username, '1900-02-08', '2900-02-08')), 0)
      ELSE 0 
    END AS "2nd line",
    CASE 
      WHEN level = 3 THEN COALESCE(SUM(get_total_investments(username, '1900-02-08', '2900-02-08')), 0)
      ELSE 0 
    END AS "3rd line"
  FROM referred_users
  WHERE level <= 3
  GROUP BY level
  INTO total_first_line, total_second_line, total_third_line;

  RETURN QUERY SELECT total_first_line, total_second_line, total_third_line;
END;
$$ LANGUAGE plpgsql;
