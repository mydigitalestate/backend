CREATE FUNCTION get_transaction_label(
  source TEXT,
  destination TEXT
) RETURNS TABLE (icon TEXT, title TEXT, amount_color TEXT) AS
$$
BEGIN
  RETURN QUERY SELECT
    CASE
    --If souce is auth user and destination is a house then icon is investment on that house
      WHEN source = get_username(auth.uid()) AND  destination ~ '^\d+$' THEN 'investment'
    --If the transaction is from you and destination is a digit, there is an investment,title = Investment on [house name],black color
       --If the transaction is from a digit and destination is you, there is a profit,title = [house name] has been booked,green color
       WHEN source ~ '^\d+$' THEN 'profit'
       --If the transaction is from a user and destination is another user both with length of name less than 20, there is a network,
       --title = [username]’s investment, green color
        WHEN LENGTH(source) < 20 AND destination=get_username(auth.uid()) THEN 'network'
         --If the transaction is from you and destination is the wallet(with more than 20 chars), there is a balance, title = Money Withdraw,
         --color red
         WHEN LENGTH(destination) > 20 THEN 'balance'
          --If the transaction is from the wallet and destination is you, there is a balance, title = Money Deposit, color black
          WHEN LENGTH(source) > 20 THEN 'balance'
      ELSE 'null'
    END AS icon,
    CASE
       WHEN get_username(auth.uid())=source AND destination ~ '^\d+$' THEN CONCAT('Investment on ', get_house_name(destination::INTEGER))
         WHEN source ~ '^\d+$' THEN CONCAT(get_house_name(get_house_from_booking(source::INTEGER)), ' has been booked ')
WHEN LENGTH(source) < 20 AND LENGTH(destination) < 20 AND (source <> get_username(auth.uid()))  THEN CONCAT(COALESCE((SELECT INITCAP(display_name) FROM profiles WHERE username = source), INITCAP(source)), '`s investment ')

            WHEN LENGTH(destination) > 20 THEN CONCAT(' Money Withdraw ')
             WHEN LENGTH(source) > 20  THEN CONCAT(' Money Deposit ')
      ELSE 'null'
    END AS title,
    CASE
    WHEN LENGTH(destination) > 20 THEN'red'
      WHEN destination ~ '^\d+$' THEN 'black'
       WHEN source ~ '^\d+$' THEN 'green'
         WHEN get_username(auth.uid())=source THEN 'black'
           WHEN LENGTH(source) > 20 THEN 'black'
      ELSE 'green'
    END AS amount_color;
END;
$$
LANGUAGE plpgsql;