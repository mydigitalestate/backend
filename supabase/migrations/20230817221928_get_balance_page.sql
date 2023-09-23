CREATE
OR REPLACE FUNCTION get_balance_page (OUT balance numeric, OUT wallet_data json) AS $$
DECLARE
  end_date DATE;
  start_date DATE;
BEGIN
  end_date := '2900-01-01';
  start_date := '1900-01-01';

  SELECT p.balance,
        COALESCE((
            SELECT json_agg(json_build_object('name', w.wallet_name, 'address', w.address, 'verified', w.is_verified))
            FROM wallets w
            WHERE p.username = w.owned_by
              AND w.wallet_name IS NOT NULL
        ), '[]'::json) AS wallet_data
        INTO balance, wallet_data 
           FROM profiles p 
    LEFT JOIN auth.users u ON p.id = u.id AND p.username = get_username(auth.uid())
    WHERE 
        p.username = get_username(auth.uid());

    IF NOT FOUND THEN
        wallet_data := '[]'::json;
    END IF;
END;
$$ LANGUAGE plpgsql;