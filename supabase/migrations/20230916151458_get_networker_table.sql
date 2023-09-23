CREATE OR REPLACE FUNCTION get_networker_table(
    username text
)
RETURNS TABLE (
    name text,
    avatar text,
    ranking text,
    my_network bigint,
    invested bigint,
    my_profits bigint,
    relation integer,
    subscribed text,
    user_name text
)
AS $$
DECLARE
    end_date DATE;
    start_date DATE;
BEGIN
    start_date := '1900-01-01';
    end_date := '2900-01-01';

    RETURN QUERY
    SELECT 
        COALESCE(INITCAP(p.display_name), INITCAP(p.username)) AS name,
        get_avatar(p.username) as avatar,
        COALESCE(p.ranking, 'No ranking') AS ranking,
        (COALESCE((SELECT COUNT(*) FROM get_network(n.username, start_date, end_date)), 0)) AS my_network,
        (COALESCE(SUM(get_total_investments(n.username, start_date, end_date))::bigint, 0)) AS invested,
        (COALESCE((SELECT SUM(profit) FROM get_profits_for_every_house(n.username, start_date, end_date))::bigint, 0) +
        COALESCE((SELECT SUM(profits) FROM get_profits_from_each_user_network(start_date, end_date, n.username))::bigint, 0)) AS my_profits,
        n.level AS relation,
        TO_CHAR(n.subscribed_at, 'DD/MM/YYYY') AS subscribed,
        p.username AS user_name
    FROM get_network(username, start_date, end_date) n
    LEFT JOIN profiles_view p ON p.username = n.username
    WHERE p.username IS NOT NULL
    GROUP BY p.display_name, p.username, n.username, p.ranking, n.level, n.subscribed_at
  ORDER BY 
    (SELECT level FROM ranking r WHERE r.name = p.ranking),
        my_network DESC, 
        invested DESC, 
        my_profits DESC, 
        n.level;
END;
$$ LANGUAGE plpgsql;