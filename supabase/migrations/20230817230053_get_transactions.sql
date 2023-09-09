CREATE OR REPLACE FUNCTION get_transactions(
   start_date date DEFAULT '1900-02-08'::date,
   end_date date DEFAULT '2900-02-08'::date
)
RETURNS TABLE(
  id int4,
  timestampts TIMESTAMPTZ,
  source VARCHAR,
  destination VARCHAR,
  amount TEXT,
  icon TEXT,
  title TEXT,
  amount_color TEXT,
  transaction_timeframe TEXT
) AS $$
BEGIN
  RETURN QUERY
    SELECT 
      t.id as id,
      t.timestamp AS timestampts, 
      t.source,
      t.destination,
      CASE
        WHEN  t.amount::text='0.00' THEN NULL
        WHEN t.source = get_username(auth.uid()) THEN '-' || t.amount::text
        WHEN t.destination = get_username(auth.uid()) THEN '+' || t.amount::text
      END AS amount,
      label.icon,
      label.title,
      label.amount_color,
      CASE
        WHEN t.timestamp >= DATE_TRUNC('day', NOW()) THEN 'TODAY'
        WHEN t.timestamp >= DATE_TRUNC('day', NOW()) - INTERVAL '1 day' THEN 'YESTERDAY'
        WHEN t.timestamp >= DATE_TRUNC('week', NOW()) THEN 'THIS WEEK'
        WHEN t.timestamp >= DATE_TRUNC('month', NOW()) THEN 'THIS MONTH'
        ELSE 'OLDER'
      END AS transaction_timeframe
    FROM transactions t
    LEFT JOIN get_transaction_label(t.source, t.destination) label ON true
    WHERE (t.source = get_username(auth.uid()) OR t.destination = get_username(auth.uid()))
      AND t.timestamp BETWEEN start_date AND end_date
    GROUP BY t.id, t.timestamp, t.source, t.destination, t.amount, label.icon, label.title, label.amount_color
    ORDER BY t.timestamp DESC
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;