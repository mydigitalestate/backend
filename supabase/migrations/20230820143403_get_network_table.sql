CREATE OR REPLACE FUNCTION get_network_table()
RETURNS TABLE (
  name text,
  username text,
  avatar text,
  relation integer,
  ranking text,
  earned decimal,
  subscribed_at timestamptz
  )
AS $$
DECLARE
    end_date DATE;
    start_date DATE;
BEGIN
    start_date := '1900-01-01';
    end_date := '2900-01-01';

    RETURN QUERY
    SELECT COALESCE(INITCAP(p.display_name), INITCAP(p.username)) AS name,
            p.username as username,
            get_avatar(p.username) as avatar,
           n.level AS relation,
           COALESCE(p.ranking, 'No ranking') AS ranking,
           (COALESCE((SELECT SUM(profit) FROM get_profits_for_every_house(n.username, start_date, end_date)), 0) +
           COALESCE((SELECT SUM(profits) FROM get_profits_from_each_user_network(start_date, end_date, n.username)), 0)) AS earned,
           n.subscribed_at
    FROM get_network(get_username(auth.uid()), start_date, end_date) n
    LEFT JOIN profiles_view p ON p.username = n.username
    WHERE p.username IS NOT NULL
    GROUP BY p.display_name, p.username, n.level, p.ranking, earned, n.subscribed_at;
END;
$$ LANGUAGE plpgsql;