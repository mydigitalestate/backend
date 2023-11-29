
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA "internal";

ALTER SCHEMA "internal" OWNER TO "postgres";

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

CREATE TYPE "public"."leaderboard_result" AS (
	"avatar" "text",
	"username" "text",
	"total_profits" numeric
);

ALTER TYPE "public"."leaderboard_result" OWNER TO "postgres";

CREATE FUNCTION "public"."airbnb_link_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO Notifications (usernames, title, message, image, link, icon) 
  VALUES (NEW.investors, 'No have airbnb link', 'House ' || NEW.name || ' did not have an Airbnb link when set to ready',
  NEW.images[1], 'investment/' || NEW.id, 'airbnb');
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."airbnb_link_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."check_notification_update_policy"("username" "text", "user_names" "text"[]) RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN (
    (username = ANY(user_names) OR user_names IS NULL)
    AND (username IS NOT NULL)
  );
END;
$$;

ALTER FUNCTION "public"."check_notification_update_policy"("username" "text", "user_names" "text"[]) OWNER TO "postgres";

CREATE FUNCTION "public"."count_bookings"("house_id_param" integer, "start_date_param" "date", "end_date_param" "date") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(house_id)
        FROM bookings
        WHERE house_id = house_id_param
        AND start_date BETWEEN start_date_param AND end_date_param
        AND end_date BETWEEN start_date_param AND end_date_param
    );
END;
$$;

ALTER FUNCTION "public"."count_bookings"("house_id_param" integer, "start_date_param" "date", "end_date_param" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_username"("uid" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN (
    SELECT username
    FROM profiles
    WHERE id = uid
  );
END;
$$;

ALTER FUNCTION "public"."get_username"("uid" "uuid") OWNER TO "postgres";

CREATE FUNCTION "public"."count_properties"("username" "text" DEFAULT "public"."get_username"("auth"."uid"())) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT investors)
    FROM houses
    WHERE username = ANY(investors)
  );
END;
$$;

ALTER FUNCTION "public"."count_properties"("username" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."create_house_ready_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.airbnb_link IS NULL OR NEW.airbnb_link = '' THEN
    RAISE EXCEPTION 'airbnb_link is not present';
  END IF;

  INSERT INTO Notifications (usernames, title, message, image, link, icon) 
  VALUES (NEW.investors, 'Ready For Bookings', NEW.name || ' is now available on Airbnb!', NEW.images[1], NEW.airbnb_link , 'airbnb');

  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."create_house_ready_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_investing_transaction"("new_destination" "text", "new_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO transactions (source, destination, amount)
  VALUES (get_username(auth.uid()), new_destination, new_amount);
END;
$$;

ALTER FUNCTION "public"."create_investing_transaction"("new_destination" "text", "new_amount" numeric) OWNER TO "postgres";

CREATE FUNCTION "public"."create_new_citizen_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  INSERT INTO public.notifications (usernames, title, message, image, link, icon)
  VALUES ( ARRAY[NEW.invited_by::text], 'New Citizen In The Network',
    CONCAT(INITCAP(NEW.username)) || ' subscribed thanks to you!', public.get_avatar(NEW.username),NEW.username, 'network');
  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."create_new_citizen_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_profile_for_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN 
 -- Check if the username contains special characters
    IF NEW.raw_user_meta_data ->> 'username' ~ '[^a-zA-Z0-9]' THEN
        RAISE EXCEPTION 'Username cannot contain special characters';
    END IF;
    -- Construct the JSONB object with the lowercased username
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('username', lower(NEW.raw_user_meta_data ->> 'username'));
    -- Set default ranking and invite_limits values
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('ranking', 'Citizen', 'invite_limits', '0');
    -- Check if the inviter is 'andreafuturi'
    IF NEW.raw_user_meta_data ->> 'invited_by' = 'andreafuturi' THEN
        NEW.raw_user_meta_data = NEW.raw_user_meta_data || jsonb_build_object('ranking', 'Centurion', 'invite_limits', '5');
    END IF;

    -- Insert the record into the profiles table
    INSERT INTO public.profiles (id, email, username, invited_by, ranking, invite_limits)
    VALUES (
        NEW.id,
        NEW.email,
        lower(NEW.raw_user_meta_data ->> 'username'),
        NEW.raw_user_meta_data ->> 'invited_by',
        (NEW.raw_user_meta_data ->> 'ranking')::text,
        (NEW.raw_user_meta_data ->> 'invite_limits')::numeric
    ); 
       
    RETURN NEW;
        END;$$;

ALTER FUNCTION "public"."create_profile_for_new_user"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_referral_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$DECLARE
  inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
  second_line_inviter_username VARCHAR(255);
  house_name VARCHAR(255);
  staff_value VARCHAR(255);

BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    -- first line inviter
    SELECT invited_by INTO inviter_username FROM public.referrals WHERE username = NEW.source;
    
    IF inviter_username IS NOT NULL THEN
      SELECT first_line_rate INTO referral_amount FROM public.ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = inviter_username);
      SELECT name INTO house_name FROM public.houses WHERE id::text = NEW.destination;
      referral_amount := (NEW.amount * referral_amount) / 100;

      IF referral_amount > 0 THEN 
      INSERT INTO public.notifications (title, message, usernames, value, image, link,color)
      VALUES ('New Investment From Network', 
              CONCAT(COALESCE((SELECT INITCAP(display_name) FROM public.profiles WHERE username = NEW.source), INITCAP(NEW.source)), ' invested ', NEW.amount, ' USDT on ', house_name, '!'),
              ARRAY[inviter_username], referral_amount , public.get_avatar(NEW.source),
                'profits/?network=true','success');
    END IF;
END IF;
    -- second line inviter
    SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.source);
    IF second_line_inviter_username IS NOT NULL THEN
      -- Check if the inviter is part of staff
        SELECT staff INTO staff_value FROM profiles_view WHERE username = second_line_inviter_username;
        IF staff_value IS NOT NULL THEN
      SELECT second_line_rate INTO referral_amount FROM public.ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = second_line_inviter_username);
      referral_amount := (NEW.amount * referral_amount) / 100;

      IF referral_amount > 0 THEN 
      INSERT INTO public.notifications (title, message, usernames, value, image, link,color)
      VALUES ('New Investment From Network', 
              CONCAT(COALESCE((SELECT INITCAP(display_name) FROM public.profiles WHERE username = NEW.source), INITCAP(NEW.source)), ' invested ', NEW.amount, ' USDT on ', house_name, '!'),
              ARRAY[second_line_inviter_username], referral_amount, public.get_avatar(NEW.source), 'profits/?network=true','success');
        END IF;
       END IF;
     END IF;
    END IF;
  RETURN NEW;
END;
$_$;

ALTER FUNCTION "public"."create_referral_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_referral_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$DECLARE
  inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
  second_line_inviter_username VARCHAR(255);
  staff_value VARCHAR(255);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    IF NEW.amount > 0 THEN 
      -- First-line referral
      SELECT invited_by INTO inviter_username FROM Referrals WHERE username = NEW.source;
      IF inviter_username IS NOT NULL THEN
        SELECT first_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM profiles_view WHERE username = inviter_username);
        referral_amount := (NEW.amount * referral_amount) / 100;
        IF referral_amount >= 0.01 THEN
          INSERT INTO Transactions (source, destination, amount) 
          VALUES (NEW.source, inviter_username ,referral_amount);
        END IF;
      END IF;

      -- Second-line referral (only if inviter is part of staff)
      SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM Referrals WHERE username = NEW.source);
      IF second_line_inviter_username IS NOT NULL THEN
        -- Check if the inviter is part of staff
        SELECT staff INTO staff_value FROM Profiles WHERE username = second_line_inviter_username;
        IF staff_value IS NOT NULL THEN
          SELECT second_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM Profiles WHERE username = second_line_inviter_username);
          referral_amount := (NEW.amount * referral_amount) / 100;
          IF referral_amount >= 0.01 THEN
            INSERT INTO Transactions (source, destination, amount) 
            VALUES (NEW.source, second_line_inviter_username , referral_amount);
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$_$;

ALTER FUNCTION "public"."create_referral_transaction"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_second_line_referral_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

DECLARE
  second_line_inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    SELECT invited_by INTO second_line_inviter_username FROM public.referrals WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.source);
    IF second_line_inviter_username IS NOT NULL THEN
      SELECT second_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM Profiles WHERE username = second_line_inviter_username);
      referral_amount := (NEW.amount * referral_amount) / 100;
      INSERT INTO public.transactions (source, destination, amount, timestamp) 
      VALUES (NEW.source, second_line_inviter_username , referral_amount, NOW());
    END IF;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."create_second_line_referral_transaction"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_third_line_referral_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  second_line_inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);
BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    IF EXISTS (SELECT 1 FROM Referrals WHERE username = NEW.source) THEN
      SELECT invited_by INTO second_line_inviter_username FROM Referrals WHERE username = (SELECT invited_by FROM Referrals WHERE username = NEW.source);
      IF second_line_inviter_username IS NOT NULL THEN
        SELECT second_line_rate INTO referral_amount FROM Ranking WHERE name = (SELECT ranking FROM Profiles WHERE username = second_line_inviter_username);
        referral_amount := (NEW.amount * referral_amount) / 100;
        INSERT INTO Transactions (source, destination, amount, timestamp) 
        VALUES (NEW.source, second_line_inviter_username , referral_amount, NOW());
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."create_third_line_referral_transaction"() OWNER TO "postgres";

CREATE FUNCTION "public"."create_widthdraw_transaction"("new_destination" "text", "new_amount" numeric, "new_status" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO transactions (source, destination, amount, status)
  VALUES (get_username(auth.uid()), new_destination, new_amount, new_status);
END;
$$;

ALTER FUNCTION "public"."create_widthdraw_transaction"("new_destination" "text", "new_amount" numeric, "new_status" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."decrease_user_balance"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

BEGIN
  IF (NEW.source !~ '^[0-9]+$' AND length(NEW.source) < 20 AND 
  NEW.destination ~ '^[0-9]+$' OR length(NEW.destination) > 20)THEN
    UPDATE Profiles
    SET balance = balance - NEW.amount
    WHERE username = NEW.source;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."decrease_user_balance"() OWNER TO "postgres";

CREATE FUNCTION "public"."delete_referral_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  DELETE FROM public.referrals
  WHERE username = OLD.username;
  RETURN NULL;
END;

$$;

ALTER FUNCTION "public"."delete_referral_func"() OWNER TO "postgres";

CREATE FUNCTION "public"."deposit_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  IF LENGTH(NEW.destination) < 20 AND LENGTH(NEW.source) > 20 THEN
    INSERT INTO Notifications (usernames, title, message, value, link, color,image) 
    VALUES (ARRAY[NEW.destination], 'Balance Deposit', 'Your deposit has arrived!', NEW.amount, 'balance','info','deposit');
  END IF;
  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."deposit_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."distribute_income_to_investors_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  value DECIMAL(10,2);
  total INT;
BEGIN
  SELECT total_required INTO total FROM Houses WHERE id = NEW.house_id;

  INSERT INTO Transactions (source, destination, amount)
    SELECT  NEW.id, unnest.investor, (SUM(amount) / total) * NEW.income
    FROM (SELECT unnest(investors) as investor FROM houses WHERE id = NEW.house_id) as unnest
    JOIN Transactions ON unnest.investor = Transactions.source and Transactions.destination = NEW.house_id::text
    GROUP BY unnest.investor;

  RETURN NULL;
END;
$$;

ALTER FUNCTION "public"."distribute_income_to_investors_func"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE "public"."houses" (
    "name" "text" NOT NULL,
    "description" "text",
    "images" "text"[],
    "price" numeric NOT NULL,
    "amount_reached" numeric DEFAULT 0 NOT NULL,
    "investment_details" "json" NOT NULL,
    "publishing_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "start_date" timestamp with time zone,
    "duration" integer NOT NULL,
    "coords" "json" NOT NULL,
    "address" "text" NOT NULL,
    "is_paid" boolean DEFAULT false NOT NULL,
    "is_ready" boolean DEFAULT false NOT NULL,
    "id" integer NOT NULL,
    "investors" "text"[],
    "total_required" numeric NOT NULL,
    "airbnb_link" "text",
    "contract_ended" boolean DEFAULT false,
    CONSTRAINT "amount_check" CHECK (("amount_reached" <= "total_required"))
);

ALTER TABLE "public"."houses" OWNER TO "postgres";

CREATE FUNCTION "public"."get_active_investments"() RETURNS SETOF "public"."houses"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
        SELECT * 
        FROM houses
        WHERE start_date + interval '1 month' * duration >= now() AND
              get_username(auth.uid()) = ANY(investors);
END;
$$;

ALTER FUNCTION "public"."get_active_investments"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_all_bookings"("house_booking_id_param" integer) RETURNS TABLE("house_booking_id" integer, "booking_id" integer)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  booking_record bookings%ROWTYPE;
BEGIN
  FOR booking_record IN SELECT * FROM public.bookings WHERE house_id = house_booking_id_param
  LOOP
    RETURN QUERY SELECT house_booking_id_param, booking_record.id;
  END LOOP;

  RETURN;
END;
$$;

ALTER FUNCTION "public"."get_all_bookings"("house_booking_id_param" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_all_houses_profits"("username" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date" "date" DEFAULT '1900-02-08'::"date", "end_date" "date" DEFAULT '2900-02-08'::"date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  total NUMERIC;
  booking_ids text[];
BEGIN
SELECT array_agg(id::text) INTO booking_ids
 FROM bookings;

  SELECT SUM(amount) INTO total 
  FROM transactions
WHERE source = ANY(booking_ids)
    AND destination = username
    AND timestamp BETWEEN start_date AND end_date;
  RETURN total;
END;
$$;

ALTER FUNCTION "public"."get_all_houses_profits"("username" "text", "start_date" "date", "end_date" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_almost_completed"() RETURNS TABLE("houseid" integer, "title" "text", "pic" "text", "invested" numeric, "reached" numeric, "total" numeric, "period" integer, "location" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT
    h.id AS houseid,
    name as title,
    images[1] as pic, 
    COALESCE(get_total_investments(h.id, get_username(auth.uid()), '1900-02-08'::date,'2900-02-08'::date),0) as invested,
    amount_reached AS reached,
    total_required as total,             
    duration as period,
    address as location
  FROM Houses h
  LEFT JOIN profiles_view p ON p.username = ANY(h.investors)
  WHERE amount_reached >= total_required * 0.9 AND amount_reached != total_required AND p.username = ANY(h.investors)
  GROUP BY h.id,h.name,h.images,h.amount_reached,h.total_required,h.duration,h.address
  ORDER BY (amount_reached - total_required) DESC;
END;
$$;

ALTER FUNCTION "public"."get_almost_completed"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_avatar"("user_name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    avatar_filename TEXT;
    result_url TEXT;
BEGIN
    -- Check if the avatar exists in Supabase storage for the given username
    SELECT name
    INTO avatar_filename
    FROM storage.objects
    WHERE bucket_id = 'avatar' AND name = user_name
    LIMIT 1;

    -- If an avatar exists, set the result URL to the avatar URL; otherwise, set it to the ranking URL
    IF avatar_filename IS NOT NULL THEN
        result_url := 'https://eklwuvlldkingzeqmlrp.supabase.co/storage/v1/object/public/avatar/' || avatar_filename;
    ELSE
        SELECT ranking
        INTO result_url
        FROM public.profiles_view
        WHERE username = user_name;
        
        result_url := 'https://eklwuvlldkingzeqmlrp.supabase.co/storage/v1/object/public/defaultAvatars/' || result_url;
    END IF;

    RETURN result_url;

END;
$$;

ALTER FUNCTION "public"."get_avatar"("user_name" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."get_balance_page"(OUT "balance" numeric, OUT "wallet_data" "json") RETURNS "record"
    LANGUAGE "plpgsql"
    AS $$
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
               WHERE p.username = get_username(auth.uid());
    IF NOT FOUND THEN
        wallet_data := '[]'::json;
    END IF;

END;
$$;

ALTER FUNCTION "public"."get_balance_page"(OUT "balance" numeric, OUT "wallet_data" "json") OWNER TO "postgres";

CREATE FUNCTION "public"."get_booked_days"("houseid" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    booked_days INT;
BEGIN
    -- Calculate the number of booked days in the past
    SELECT COALESCE(SUM(b.end_date::DATE - b.start_date::DATE))
            -- CASE
            --     WHEN (b.start_date::DATE <= CURRENT_DATE AND b.end_date::DATE >= h.start_date::DATE) THEN
            --         LEAST(b.end_date::DATE, CURRENT_DATE) - GREATEST(h.start_date::DATE, b.start_date::DATE)
            --     ELSE 0
            -- END), 0)
    INTO booked_days
    FROM bookings b
    JOIN houses h ON b.house_id = h.id
    WHERE b.house_id = houseid;

    RETURN booked_days;
END;
$$;

ALTER FUNCTION "public"."get_booked_days"("houseid" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_completed_properties"() RETURNS SETOF "public"."houses"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY SELECT * FROM houses WHERE amount_reached >= total_required;
END;
$$;

ALTER FUNCTION "public"."get_completed_properties"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_contest_leaderboard"() RETURNS SETOF "public"."leaderboard_result"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_record leaderboard_result;
BEGIN
    FOR result_record IN (
        SELECT 
            get_avatar(username) as avatar,
            username,
            total_profits
        FROM (
            SELECT 
                get_avatar(p.username),
                username,
                total_profits,
                ROW_NUMBER() OVER (ORDER BY total_profits DESC) as position
            FROM profiles p
        ) top_users
        WHERE position <= 5
    ) LOOP
        RETURN NEXT result_record;
    END LOOP;
END;
$$;

ALTER FUNCTION "public"."get_contest_leaderboard"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_dashboard_page"(OUT "my_investments" numeric, OUT "investment_increase" numeric, OUT "my_profits" numeric, OUT "profits_increase" numeric, OUT "my_network" integer, OUT "network_increase" numeric, OUT "almost_completed" "json", OUT "amount" numeric[], OUT "this_day_profits" numeric, OUT "new_houses" "json") RETURNS "record"
    LANGUAGE "plpgsql"
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

week_days := ARRAY(SELECT generate_series(week_start_date, week_end_date, '1 day'::interval)::date);

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

SELECT array_agg(total_amount) INTO amount FROM temp_results;

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

$$;

ALTER FUNCTION "public"."get_dashboard_page"(OUT "my_investments" numeric, OUT "investment_increase" numeric, OUT "my_profits" numeric, OUT "profits_increase" numeric, OUT "my_network" integer, OUT "network_increase" numeric, OUT "almost_completed" "json", OUT "amount" numeric[], OUT "this_day_profits" numeric, OUT "new_houses" "json") OWNER TO "postgres";

CREATE FUNCTION "public"."get_email_template"("template_type" "text", "link" "text", "language" "text" DEFAULT 'en'::"text") RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'internal'
    AS $$
DECLARE
  email_subject TEXT;
  email_content TEXT;
  email_json JSON;
BEGIN
  SELECT subject, REPLACE(content, '{{LINK}}', link) INTO email_subject, email_content
  FROM internal.email_templates
  WHERE email_type = template_type AND email_language = language;
  email_json := json_build_object('subject', email_subject, 'content', email_content);
  RETURN email_json;
END;
$$;

ALTER FUNCTION "public"."get_email_template"("template_type" "text", "link" "text", "language" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."get_house_from_booking"("booking_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  house_id_val INTEGER;
BEGIN
  SELECT house_id INTO house_id_val FROM bookings WHERE id = booking_id;
  RETURN house_id_val;
END;
$$;

ALTER FUNCTION "public"."get_house_from_booking"("booking_id" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_house_name"("house_id" integer) RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  house_name TEXT;
BEGIN
  SELECT name INTO house_name FROM houses WHERE id = house_id;
  RETURN house_name;
END;
$$;

ALTER FUNCTION "public"."get_house_name"("house_id" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_invested_amount"("houseid" integer) RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  total NUMERIC;
BEGIN
  SELECT SUM(amount) INTO total
  FROM transactions
  WHERE destination = houseid::text;
  RETURN total;
END;
$$;

ALTER FUNCTION "public"."get_invested_amount"("houseid" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_investment"("uid" "uuid", "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    total_investment numeric;
BEGIN
    WITH RECURSIVE referrals_res(username, invited_by, subscribed_at) AS (
        SELECT username, invited_by, subscribed_at FROM public.referrals WHERE username = get_username(uid)
        UNION ALL
        SELECT u.username, u.invited_by, r.subscribed_at FROM referrals r, referrals u 
        WHERE r.username = u.invited_by AND r.subscribed_at BETWEEN start_date_val AND end_date_val
    )
    SELECT SUM(get_total_investments(username, start_date_val, end_date_val)) INTO total_investment
    FROM referrals_res WHERE username ='tiberius';
    
    RETURN total_investment;
END;
$$;

ALTER FUNCTION "public"."get_investment"("uid" "uuid", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_investment_page"("h_id" integer, OUT "title" "text", OUT "pic" "text"[], OUT "location" "text", OUT "duration" integer, OUT "price" numeric, OUT "description" "text", OUT "my_investment" numeric, OUT "network_investments" numeric, OUT "missing_investments" numeric, OUT "total_required" numeric, OUT "my_profits" numeric, OUT "network_profits" numeric, OUT "top_investors" "json", OUT "similar_houses" "json", OUT "is_ready" boolean, OUT "is_investor" boolean, OUT "current_roi" numeric, OUT "current_roi_percentage" numeric, OUT "bookings" numeric, OUT "total_days_passed" numeric, OUT "occupancy_rate" numeric, OUT "missing_time" numeric, OUT "investment_details" "json", OUT "daily_investment_cost" numeric, OUT "investment_used_now" numeric, OUT "total_contract_days" numeric) RETURNS "record"
    LANGUAGE "plpgsql"
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
$$;

ALTER FUNCTION "public"."get_investment_page"("h_id" integer, OUT "title" "text", OUT "pic" "text"[], OUT "location" "text", OUT "duration" integer, OUT "price" numeric, OUT "description" "text", OUT "my_investment" numeric, OUT "network_investments" numeric, OUT "missing_investments" numeric, OUT "total_required" numeric, OUT "my_profits" numeric, OUT "network_profits" numeric, OUT "top_investors" "json", OUT "similar_houses" "json", OUT "is_ready" boolean, OUT "is_investor" boolean, OUT "current_roi" numeric, OUT "current_roi_percentage" numeric, OUT "bookings" numeric, OUT "total_days_passed" numeric, OUT "occupancy_rate" numeric, OUT "missing_time" numeric, OUT "investment_details" "json", OUT "daily_investment_cost" numeric, OUT "investment_used_now" numeric, OUT "total_contract_days" numeric) OWNER TO "postgres";

CREATE FUNCTION "public"."get_investments_page"(OUT "total_investments" numeric, OUT "active_investments" numeric, OUT "locked_investments" numeric, OUT "completed_investments" numeric, OUT "total_properties" numeric, OUT "active_properties" numeric, OUT "locked_properties" numeric, OUT "completed_properties" numeric, OUT "my_properties" "json", OUT "amounts" numeric[]) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    end_date DATE;
    start_date DATE;
    month_val INT;
    year_val INT;
    i INT;
BEGIN
    end_date := '2900-01-01';
    start_date := '1900-01-01';
    month_val := EXTRACT(MONTH FROM CURRENT_DATE);
    year_val := EXTRACT(YEAR FROM CURRENT_DATE);
    i := 0;

    BEGIN
   WITH active_house_id AS (
  SELECT id FROM get_active_investments()
)
SELECT COALESCE(SUM(t.amount), 0) INTO active_investments 
FROM transactions t
JOIN active_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());

    WITH locked_house_id AS (
  SELECT id FROM get_locked_investments()
)
SELECT COALESCE(SUM(t.amount), 0) INTO locked_investments 
FROM transactions t
JOIN locked_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());

   WITH completed_house_id AS (
  SELECT id FROM get_completed_properties()
)
SELECT COALESCE(SUM(t.amount), 0) INTO completed_investments 
FROM transactions t
JOIN completed_house_id h
ON t.destination = h.id::text 
WHERE t.source = get_username(auth.uid());

        -- total_investments := active_investments + locked_investments + completed_investments;
        SELECT COALESCE(p.total_investments, 0) FROM profiles p INTO total_investments
         WHERE
            p.username = get_username(auth.uid())
        GROUP BY
            p.total_investments;

        SELECT COUNT(*) INTO active_properties FROM get_active_investments();
        SELECT COUNT(*) INTO locked_properties FROM get_locked_investments();
        SELECT COUNT(*) INTO completed_properties FROM get_completed_properties();
        total_properties := active_properties + locked_properties + completed_properties;

    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            active_investments := 0;
            locked_investments := 0;
            completed_investments := 0;
            total_investments := 0;
            active_properties := 0;
            locked_properties := 0;
            completed_properties := 0;
            total_properties := 0;
    END;

    SELECT json_agg(t) INTO my_properties
    FROM (
        SELECT * FROM get_properties(start_date, end_date)
    ) t;

    amounts := ARRAY(
        SELECT COALESCE(SUM(amount), 0)
        FROM (
            SELECT DISTINCT m AS month
            FROM generate_series(1, 12) AS m
        ) months
        LEFT JOIN transactions ON transactions.source = get_username(auth.uid())
            AND transactions.destination ~ '^\d+$'
            AND transactions.timestamp BETWEEN make_date(year_val, months.month, 1)
                AND (make_date(year_val, months.month, 1) + interval '1 month' - interval '1 day')
        GROUP BY months.month
        ORDER BY months.month
    );

END;
$_$;

ALTER FUNCTION "public"."get_investments_page"(OUT "total_investments" numeric, OUT "active_investments" numeric, OUT "locked_investments" numeric, OUT "completed_investments" numeric, OUT "total_properties" numeric, OUT "active_properties" numeric, OUT "locked_properties" numeric, OUT "completed_properties" numeric, OUT "my_properties" "json", OUT "amounts" numeric[]) OWNER TO "postgres";

CREATE FUNCTION "public"."get_invited_users"("username" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("referred_username" "text", "referred_at" timestamp without time zone)
    LANGUAGE "sql"
    AS $$
WITH RECURSIVE invited_by_users(referred_username, invited_at) AS (
  SELECT username, subscribed_at
  FROM public.referrals
  WHERE invited_by = username AND subscribed_at BETWEEN start_date_val AND end_date_val
  UNION
  SELECT r.username, r.subscribed_at
  FROM invited_by_users ru
  JOIN public.referrals r ON r.invited_by = ru.referred_username
)
SELECT referred_username, invited_at
FROM invited_by_users;
$$;

ALTER FUNCTION "public"."get_invited_users"("username" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_last_investments"("username" "text", "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("house_id" integer, "title" "text", "pic" "text", "location" "text", "duration" integer, "total_required" numeric, "total_profits" "json", "personal_invested_amount" numeric, "total_investments" numeric, "last_transaction" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    h.id AS house_id,
    h.name AS title,
    h.images[1] AS pic,
    h.address AS location,
    h.duration AS duration,
    h.total_required AS total_required,
    (
      SELECT json_agg(k)
      FROM (
        SELECT *
        FROM get_total_profits(h.id, username, start_date_val, end_date_val)
      ) k
    ) AS total_profits,
    COALESCE(get_total_investments(h.id, username, start_date_val, end_date_val), 0) AS personal_invested_amount,
    COALESCE(get_invested_amount(h.id), 0) AS total_investments,
    MAX(t.timestamp) AS last_transaction
  FROM houses h
  LEFT JOIN transactions t ON h.id::text = t.destination
  WHERE username = ANY(
    h.investors) AND t.source = username
  GROUP BY h.id, h.name
  ORDER BY last_transaction DESC NULLS LAST;
END;
$$;

ALTER FUNCTION "public"."get_last_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_locked_investments"() RETURNS SETOF "public"."houses"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM houses
        WHERE amount_reached < total_required
        AND get_username(auth.uid()) = ANY(investors);
END;
$$;

ALTER FUNCTION "public"."get_locked_investments"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_market"("start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("house_id" integer, "title" "text", "pic" "text", "location" "text", "duration" integer, "total_required" numeric, "price" numeric, "personal_invested_amount" numeric, "total_investments" numeric, "total_profits" "json", "invested_dates" timestamp with time zone[], "profited_dates" timestamp with time zone[], "is_locked" boolean, "coordinates" "json")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT 
    h.id as house_id,
    h.name as title, 
    h.images[1] as pic, 
    h.address as location,
    h.duration as duration,
    h.total_required as total_required,
    h.price AS price,
    COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val), 0) as personal_invested_amount,
    -- COALESCE(get_invested_amount(h.id), 0) as total_investments,
    h.amount_reached as total_investments,
    row_to_json(get_total_profits(h.id, get_username(auth.uid()), start_date_val, end_date_val)) as total_profits,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = get_username(auth.uid())
        AND t.destination = h.id::text
    ) as invested_dates,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = h.id::text 
        AND t.destination = get_username(auth.uid())
    ) as profited_dates,
    h.id IN (SELECT id FROM get_locked_investments()) as is_locked,
    h.coords as coordinates
  FROM houses h
  WHERE h.amount_reached < h.total_required;

END;
$$;

ALTER FUNCTION "public"."get_market"("start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_network"("name" "text", "start_date_val" "date", "end_date_val" "date") RETURNS TABLE("username" "text", "invited_by" "text", "level" integer, "subscribed_at" timestamp with time zone)
    LANGUAGE "sql"
    AS $$
WITH RECURSIVE referred_users(username, invited_by, level, subscribed_at) AS (
  SELECT username, invited_by, 0, subscribed_at 
  FROM public.referrals
  WHERE username = name
  UNION ALL
  SELECT r.username, r.invited_by, ru.level + 1, r.subscribed_at
  FROM public.referrals r
  JOIN referred_users ru ON r.invited_by = ru.username
)
SELECT username, invited_by, level , subscribed_at
FROM referred_users
WHERE subscribed_at BETWEEN start_date_val AND end_date_val
  AND username <> name;
$$;

ALTER FUNCTION "public"."get_network"("name" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_network_investment"("user_name" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS numeric
    LANGUAGE "sql"
    AS $$
WITH RECURSIVE referred_users(username, invited_by) AS (
  SELECT username, invited_by, subscribed_at
  FROM public.referrals
  WHERE invited_by = user_name  AND subscribed_at BETWEEN start_date_val AND end_date_val
  UNION
  SELECT r.username, r.invited_by, r.subscribed_at
  FROM referred_users ru
  JOIN public.referrals r ON r.invited_by = ru.username
)
SELECT 
  COALESCE(SUM(get_total_investments(username, start_date_val, end_date_val)), 0) AS overall_investments
FROM referred_users;
$$;

ALTER FUNCTION "public"."get_network_investment"("user_name" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_network_lines_investment"() RETURNS TABLE("1st line" numeric, "2nd line" numeric, "3rd line" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  total_first_line NUMERIC := 0;
  total_second_line NUMERIC := 0;
  total_third_line NUMERIC := 0;
BEGIN
  WITH RECURSIVE referred_users(username, invited_by, level) AS (
    SELECT username, invited_by, 1
    FROM public.referrals
    WHERE invited_by = get_username(auth.uid()) AND subscribed_at BETWEEN '1900-02-08' AND '2900-02-08'
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
$$;

ALTER FUNCTION "public"."get_network_lines_investment"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_network_page"(OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_line_network" numeric, OUT "total_investments" numeric, OUT "first_line_investments" numeric, OUT "second_line_investments" numeric, OUT "other_line_investments" numeric, OUT "my_network" "json", OUT "amount" numeric[], OUT "limits_left" integer, OUT "referral_profit_rate" integer) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $_$
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
FROM profiles p
JOIN ranking r ON p.ranking = r.name
WHERE p.username = get_username(auth.uid()) AND r.first_line_rate IS NULL;

    RETURN;

END;
$_$;

ALTER FUNCTION "public"."get_network_page"(OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_line_network" numeric, OUT "total_investments" numeric, OUT "first_line_investments" numeric, OUT "second_line_investments" numeric, OUT "other_line_investments" numeric, OUT "my_network" "json", OUT "amount" numeric[], OUT "limits_left" integer, OUT "referral_profit_rate" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_network_table"() RETURNS TABLE("name" "text", "user_name" "text", "avatar" "text", "relation" integer, "ranking" "text", "earned" numeric, "subscribed_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    end_date DATE;
    start_date DATE;
BEGIN
    start_date := '1900-01-01';
    end_date := '2900-01-01';

    RETURN QUERY
    SELECT COALESCE(INITCAP(p.display_name), INITCAP(p.username)) AS name,
            p.username as user_name,
            get_avatar(p.username) as avatar,
           n.level AS relation,
           COALESCE(p.ranking, 'No ranking') AS ranking,
          (COALESCE((SELECT profits FROM get_profits_from_each_user_network(start_date, end_date, get_username(auth.uid()))g 
           where g.username = n.username), 0)) AS earned,
           n.subscribed_at
    FROM get_network(get_username(auth.uid()), start_date, end_date) n
    LEFT JOIN profiles_view p ON p.username = n.username
    WHERE p.username IS NOT NULL
    GROUP BY p.display_name, p.username, n.level, p.ranking, earned, n.subscribed_at
    ORDER BY earned DESC, relation ASC,         
    (SELECT level FROM ranking r WHERE r.name = p.ranking);

END;
$$;

ALTER FUNCTION "public"."get_network_table"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_networker_table"("username" "text") RETURNS TABLE("name" "text", "avatar" "text", "ranking" "text", "my_network" bigint, "invested" bigint, "my_profits" bigint, "relation" integer, "subscribed" "text", "user_name" "text")
    LANGUAGE "plpgsql"
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
$$;

ALTER FUNCTION "public"."get_networker_table"("username" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."get_new_houses"() RETURNS TABLE("house_id" integer, "name" "text", "duration" integer, "address" "text", "price" numeric, "pic" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY SELECT h.id, h.name, h.duration, h.address, h.price, h.images[1]
                  FROM houses h
                  WHERE (h.publishing_date BETWEEN now() - interval '30 days' AND now()) AND h.amount_reached < h.total_required;

END;
$$;

ALTER FUNCTION "public"."get_new_houses"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_notifications"("start_date" "date" DEFAULT '1900-02-08'::"date", "end_date" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("id" integer, "title" "text", "image" "text", "message" "text", "date" timestamp with time zone, "link" "text", "period" "text", "value" "text", "color" "text", "icon" "text", "read" "text"[], "usernames" "text"[])
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  user_created_at TIMESTAMPTZ;
  endDate date;
  week_start_date date;
  week_end_date date;
  yesterday_start_date date;
BEGIN
  SELECT subscribed_at INTO user_created_at FROM referrals r WHERE r.username = get_username(auth.uid());

  -- Calculate week start and end dates
  endDate := CURRENT_DATE;
  week_start_date := date_trunc('week', endDate)::date;
  week_end_date := (date_trunc('week', endDate) + '6 days')::date;
  yesterday_start_date := date_trunc('day', NOW() - INTERVAL '1 day')::date;

  RETURN QUERY
  SELECT n.id, n.title, n.image, n.message, n.date, n.link,
    CASE
      WHEN (get_username(auth.uid()) NOT IN (SELECT unnest(n.read))) THEN 'UNREAD'
      WHEN n.date >= DATE_TRUNC('day', NOW()) THEN 'TODAY'
      WHEN n.date >= yesterday_start_date THEN 'YESTERDAY'
      WHEN n.date BETWEEN week_start_date AND week_end_date THEN 'THIS WEEK'
      WHEN n.date >= NOW() - INTERVAL '30 day' THEN 'THIS MONTH'
      ELSE 'OLDER'
    END as period,
    CASE
      WHEN n.value = 0.00 THEN '0.00'
      ELSE '+' || n.value::text
    END as value,
    n.color, n.icon, n.read, n.usernames
  FROM notifications n
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND (n.date >= COALESCE(user_created_at, start_date))
  ORDER BY n.id DESC
  LIMIT 100;

  -- Update the read array for unread notifications
  UPDATE notifications n
  SET read = array_append(COALESCE(n.read, '{}'), get_username(auth.uid()))
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND NOT EXISTS (
      SELECT 1
      FROM unnest(n.read) AS r
      WHERE r = get_username(auth.uid()) OR r IS NULL
    )
    AND (n.date BETWEEN start_date AND end_date OR start_date IS NULL OR end_date IS NULL);

END;
$$;

ALTER FUNCTION "public"."get_notifications"("start_date" "date", "end_date" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_past_investments"() RETURNS SETOF "public"."houses"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM houses
        WHERE start_date + interval '1 month' * duration <= now();
END;
$$;

ALTER FUNCTION "public"."get_past_investments"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_profile_page"("profile_username" "text", OUT "avatar" "text", OUT "display_name" "text", OUT "public_profile" boolean, OUT "top_investments" "json", OUT "networker_table" "json", OUT "last_investments" "json", OUT "usernames" "text"[], OUT "ranking" "text", OUT "days_since_signup" integer) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    end_date DATE;
    start_date DATE;
BEGIN
    end_date := '2900-01-01';
    start_date := '1900-01-01';

   SELECT 
    get_avatar(p.username) as avatar,
    INITCAP(p.display_name), 
    p.public_profile, 
    CASE 
        WHEN p.staff <> '' THEN 'MDE ' || p.staff
        ELSE p.ranking 
    END as ranking 
INTO avatar, display_name, public_profile, ranking 
FROM profiles_view p
WHERE p.username = profile_username
GROUP BY p.username, p.display_name, p.public_profile, p.ranking, p.staff;

    SELECT array_agg(p.username) INTO usernames
    FROM profiles_view p;

    SELECT COALESCE(json_agg(t), '[]'::json) INTO top_investments
    FROM (SELECT * FROM get_top_investments(profile_username) LIMIT 3) t; 

    SELECT COALESCE(json_agg(t), '[]'::json) INTO networker_table
    FROM (SELECT * FROM get_networker_table(profile_username) LIMIT 8) t;   
    
    SELECT COALESCE(json_agg(t), '[]'::json) INTO last_investments
    FROM (SELECT * FROM get_last_investments(profile_username, start_date, end_date) LIMIT 10) t;

    SELECT EXTRACT(DAY FROM NOW() - r.subscribed_at) INTO days_since_signup
    FROM referrals r
    WHERE r.username = profile_username;

END;
$$;

ALTER FUNCTION "public"."get_profile_page"("profile_username" "text", OUT "avatar" "text", OUT "display_name" "text", OUT "public_profile" boolean, OUT "top_investments" "json", OUT "networker_table" "json", OUT "last_investments" "json", OUT "usernames" "text"[], OUT "ranking" "text", OUT "days_since_signup" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_profits_for_every_house"("username" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("house_id" integer, "profit" numeric)
    LANGUAGE "plpgsql"
    AS $$
BEGIN

  RETURN QUERY
  SELECT bookings.house_id, SUM(transactions.amount) as profit
  FROM transactions
  JOIN bookings ON bookings.id::text = transactions.source
  WHERE transactions.destination = username
    AND transactions.timestamp BETWEEN start_date_val AND end_date_val
  GROUP BY bookings.id;
END;
$$;

ALTER FUNCTION "public"."get_profits_for_every_house"("username" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_profits_from_each_user_network"("start_date_val" "date", "end_date_val" "date", "name" "text" DEFAULT "public"."get_username"("auth"."uid"())) RETURNS TABLE("username" "text", "invited_by" "text", "level" integer, "profits" numeric)
    LANGUAGE "sql"
    AS $_$
SELECT
  gn.username,
  gn.invited_by,
  gn.level,
  SUM(t.amount) AS profits
FROM
  get_network(name, '1900-02-08', '2900-02-08') gn
   JOIN public.transactions t
    ON t.source = gn.username AND t.destination = name  -- from users of his network
    -- ON t.source ~'^\d+$' AND t.destination = name  ---> from every user
    AND t.timestamp BETWEEN start_date_val AND end_date_val
GROUP BY
  gn.username,
  gn.invited_by,
  gn.level
  ORDER BY level;
$_$;

ALTER FUNCTION "public"."get_profits_from_each_user_network"("start_date_val" "date", "end_date_val" "date", "name" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."get_profits_from_network_lines"("name" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("level" integer, "profits" numeric, "usernames" "text"[])
    LANGUAGE "sql"
    AS $$
SELECT
  gn.level,
  SUM(t.amount) AS profits,
  array_agg(DISTINCT gn.username ORDER BY gn.username) AS usernames
FROM
  get_network(name, start_date_val, end_date_val) gn
  LEFT JOIN public.transactions t
    ON t.source = gn.username AND t.destination = name
    AND t.timestamp BETWEEN start_date_val AND end_date_val
GROUP BY
  gn.invited_by,
  gn.level
ORDER BY 
  gn.level;
$$;

ALTER FUNCTION "public"."get_profits_from_network_lines"("name" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_profits_page"(OUT "total_properties_profits" numeric, OUT "six_month_contract_profit" numeric, OUT "twelve_month_contract_profit" numeric, OUT "life_time_contract_profit" numeric, OUT "total_bookings" numeric, OUT "six_month_contract_booking" numeric, OUT "twelve_month_contract_booking" numeric, OUT "life_time_contract_booking" numeric, OUT "total_network_profits" numeric, OUT "first_line_profits" numeric, OUT "second_line_profits" numeric, OUT "other_lines_profits" numeric, OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_lines_network" numeric, OUT "my_properties" "json", OUT "my_network" "json", OUT "amounts" numeric[]) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    end_date DATE;
    start_date DATE;
    month_val INT;
    year_val INT;
    i INT;
BEGIN
    end_date := '2900-01-01';
    start_date := '1900-01-01';
    month_val := EXTRACT(MONTH FROM CURRENT_DATE);
    year_val := EXTRACT(YEAR FROM CURRENT_DATE);
    i := 0;

    BEGIN
        SELECT COALESCE(SUM(profit), 0)
        INTO six_month_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration = 6;
        SELECT COALESCE(SUM(profit), 0)
        INTO twelve_month_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration = 12;
        SELECT COALESCE(SUM(profit), 0)
        INTO life_time_contract_profit
        FROM get_profits_for_every_house(get_username(auth.uid()), start_date, end_date) g
        JOIN houses h ON g.house_id = h.id
        WHERE h.duration IS NULL;

        total_properties_profits := six_month_contract_profit + twelve_month_contract_profit + life_time_contract_profit;

        -- SELECT p.total_profits
        -- INTO total_properties_profits
        -- FROM profiles p
        -- WHERE p.username=get_username(auth.uid());

       SELECT COALESCE(COUNT(*), 0) INTO six_month_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration = 6 AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;

       SELECT COALESCE(COUNT(*), 0) INTO twelve_month_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration = 12 AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;

       SELECT COALESCE(COUNT(*), 0) INTO life_time_contract_booking
        FROM (SELECT id FROM houses
            WHERE duration IS NULL AND get_username(auth.uid()) = ANY(investors)
        ) AS g
        JOIN get_all_bookings(g.id) AS b ON g.id = house_booking_id;       

        total_bookings := six_month_contract_booking + twelve_month_contract_booking + life_time_contract_booking;

        SELECT COALESCE(SUM(profits), 0)
        INTO first_line_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 1;
        SELECT COALESCE(SUM(profits), 0)
        INTO second_line_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 2;
        SELECT COALESCE(SUM(profits), 0)
        INTO other_lines_profits
        FROM get_profits_from_network_lines(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level > 2;

        total_network_profits := first_line_profits + second_line_profits + other_lines_profits;

        SELECT COALESCE(COUNT(*), 0)
        INTO first_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 1;
        SELECT COALESCE(COUNT(*), 0)
        INTO second_line_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level = 2;
        SELECT COALESCE(COUNT(*), 0)
        INTO other_lines_network
        FROM get_network(get_username(auth.uid()), start_date, end_date) g
        WHERE g.level > 2;

        total_network := first_line_network + second_line_network + other_lines_network;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            six_month_contract_profit := 0;
            twelve_month_contract_profit := 0;
            life_time_contract_profit := 0;
            total_properties_profits := 0;
            six_month_contract_booking := 0;
            twelve_month_contract_booking := 0;
            life_time_contract_booking := 0;
            total_bookings := 0;
            first_line_profits := 0;
            second_line_profits := 0;
            other_lines_profits := 0;
            total_network_profits := 0;
            first_line_network := 0;
            second_line_network := 0;
            other_lines_network := 0;
            total_network := 0;
    END;

    SELECT json_agg(t) INTO my_properties
    FROM (
        SELECT * FROM get_properties(start_date, end_date)
    ) t;

    SELECT COALESCE(json_agg(k), '[]'::json) INTO my_network
    FROM (
        SELECT * FROM get_network_table()
    ) k;

    amounts := ARRAY(
        SELECT COALESCE(SUM(amount), 0) 
        FROM (
            SELECT DISTINCT m AS month
            FROM generate_series(1, 12) AS m
        ) months
        LEFT JOIN transactions ON transactions.source IS NOT NULL
            AND transactions.destination = get_username(auth.uid())
            AND transactions.timestamp BETWEEN make_date(year_val, months.month, 1)
            AND (make_date(year_val, months.month, 1) + interval '1 month' - interval '1 day')
        GROUP BY months.month
        ORDER BY months.month
    );

    RETURN;

END;
$$;

ALTER FUNCTION "public"."get_profits_page"(OUT "total_properties_profits" numeric, OUT "six_month_contract_profit" numeric, OUT "twelve_month_contract_profit" numeric, OUT "life_time_contract_profit" numeric, OUT "total_bookings" numeric, OUT "six_month_contract_booking" numeric, OUT "twelve_month_contract_booking" numeric, OUT "life_time_contract_booking" numeric, OUT "total_network_profits" numeric, OUT "first_line_profits" numeric, OUT "second_line_profits" numeric, OUT "other_lines_profits" numeric, OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_lines_network" numeric, OUT "my_properties" "json", OUT "my_network" "json", OUT "amounts" numeric[]) OWNER TO "postgres";

CREATE FUNCTION "public"."get_properties"("start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("house_id" integer, "title" "text", "pic" "text", "location" "text", "duration" integer, "total_required" numeric, "personal_invested_amount" numeric, "total_investments" numeric, "total_profits" "json", "invested_dates" timestamp with time zone[], "profited_dates" timestamp with time zone[], "is_locked" boolean, "coords" "json")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT 
    h.id as house_id,
    h.name as title, 
    h.images[1] as pic, 
    h.address as location,
    h.duration as duration,
    h.total_required as total_required,
    COALESCE(get_total_investments(h.id, get_username(auth.uid()), start_date_val, end_date_val), 0) as personal_invested_amount,
    COALESCE(get_invested_amount(h.id), 0) as total_investments,
    row_to_json(get_total_profits(h.id, get_username(auth.uid()), start_date_val, end_date_val)) as total_profits,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = get_username(auth.uid())
        AND t.destination = h.id::text
    ) as invested_dates,
    ARRAY(
      SELECT t.timestamp
      FROM transactions t
      WHERE t.source = h.id::text 
        AND t.destination = get_username(auth.uid())
    ) as profited_dates,
    h.id IN (SELECT id FROM get_locked_investments()) as is_locked,
    h.coords 
  FROM houses h
  WHERE get_username(auth.uid()) = ANY(h.investors);

END;
$$;

ALTER FUNCTION "public"."get_properties"("start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_recent_houses"() RETURNS TABLE("title" "text", "pics" "text"[], "cost" numeric, "period" integer, "location" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT name as title, images as pics, price as cost, duration as period, address as location
  FROM Houses
  WHERE publishing_date BETWEEN (now() - INTERVAL '7 days') AND now()
  ORDER BY publishing_date DESC;
END;
$$;

ALTER FUNCTION "public"."get_recent_houses"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_settings_page"(OUT "username" "text", OUT "display_name" "text", OUT "email" "text", OUT "phone" "text", OUT "email_change" character varying, OUT "confirmed_email" character varying, OUT "wallet_data" "json", OUT "profile_public" boolean) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    SELECT 
        p.username AS username,
        p.display_name AS display_name, 
        p.email AS email,
        p.phone AS phone,
        p.email AS confirmed_email, 
        COALESCE((
            SELECT json_agg(json_build_object('name', w.wallet_name, 'address', w.address, 'verified', w.is_verified))
            FROM wallets w
            WHERE p.username = w.owned_by
              AND w.wallet_name IS NOT NULL
        ), '[]'::json) AS wallet_data,
        p.public_profile AS profile_public
    INTO
        username,
        display_name,
        email,
        phone,
        confirmed_email,
        wallet_data,
        profile_public
    FROM 
        profiles p 
    WHERE 
        p.username = get_username(auth.uid());

    IF NOT FOUND THEN
        username := NULL;
        display_name := NULL;
        email := NULL;
        phone := NULL;
        confirmed_email := NULL;
        wallet_data := '[]'::json;
        profile_public := false;
    END IF;
END;$$;

ALTER FUNCTION "public"."get_settings_page"(OUT "username" "text", OUT "display_name" "text", OUT "email" "text", OUT "phone" "text", OUT "email_change" character varying, OUT "confirmed_email" character varying, OUT "wallet_data" "json", OUT "profile_public" boolean) OWNER TO "postgres";

CREATE FUNCTION "public"."get_similar_houses"("houseid" integer) RETURNS TABLE("house_id" integer, "title" "text", "pic" "text", "location" "text", "duration" integer, "house_price" numeric, "total_required" numeric, "personal_invested_amount" numeric, "amount_reached" numeric)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        h.id AS house_id,
        h.name AS title,
        h.images[1] AS pic,
        h.address AS location,
        h.duration AS duration,
        h.price AS house_price,
        h.total_required AS total_required,
        COALESCE(get_total_investments(h.id, get_username(auth.uid()), '1900-01-01', '2900-01-01'), 0) AS personal_invested_amount,
        h.amount_reached AS amount_reached
    FROM houses h
    WHERE h.id != houseid AND h.amount_reached < h.total_required
    ORDER BY random();
END;
$$;

ALTER FUNCTION "public"."get_similar_houses"("houseid" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."get_top_investments"("username" "text", "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("house_id" integer, "title" "text", "pic" "text", "location" "text", "duration" integer, "total_required" numeric, "personal_invested_amount" numeric, "total_investments" numeric, "total_profits" "json")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT 
      h.id as house_id,
      h.name as title, 
      h.images[1] as pic, 
      h.address as location,
      h.duration as duration,
      h.total_required as total_required,
      COALESCE(get_total_investments(h.id, username, start_date_val, end_date_val), 0) as personal_invested_amount,
      COALESCE(get_invested_amount(h.id), 0) as total_investments,
      (SELECT json_agg(k) FROM (
          SELECT * FROM get_total_profits(h.id, username, start_date_val, end_date_val)
      ) k) as total_profits
  FROM houses h
  WHERE username = ANY(h.investors)
  ORDER BY (SELECT COALESCE(SUM(my_profits), 0) FROM get_total_profits(h.id, username, start_date_val, end_date_val)) DESC NULLS LAST;
END;
$$;

ALTER FUNCTION "public"."get_top_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_top_investors"("house_id" integer, "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("username" "text", "avatar" "text", "name" "text", "personal_invested_amount" numeric, "required_amount" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  req_amount numeric;
BEGIN
  SELECT total_required INTO req_amount FROM houses WHERE id = house_id;
  
  RETURN QUERY SELECT 
  p.username AS username,
    get_avatar(p.username) as avatar,
    COALESCE(INITCAP(p.display_name), INITCAP(p.username)) AS name,
    COALESCE(get_total_investments(house_id, p.username, start_date_val, end_date_val), 0) AS personal_invested_amount,
    req_amount AS required_amount
  FROM profiles_view p
  INNER JOIN houses h ON p.username = ANY(h.investors) AND h.id = house_id
  ORDER BY personal_invested_amount DESC NULLS LAST;
END;
$$;

ALTER FUNCTION "public"."get_top_investors"("house_id" integer, "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_total_investments"("user_name" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    total NUMERIC;
BEGIN
    SELECT SUM(amount) INTO total
    FROM transactions
    WHERE source = user_name
    AND destination ~ '^\d+$'
    AND timestamp >= start_date_val
    AND timestamp <= end_date_val + INTERVAL '1 day'; --added this because the the end_date_val was not included and the result was wrong
    
    RETURN total;
END;
$_$;

ALTER FUNCTION "public"."get_total_investments"("user_name" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_total_investments"("house_id_val" integer, "user_name" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date_val" "date" DEFAULT '1900-02-08'::"date", "end_date_val" "date" DEFAULT '2900-02-08'::"date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  invested_amount_val NUMERIC;
BEGIN
  SELECT SUM(amount) INTO invested_amount_val 
  FROM transactions
  WHERE source = user_name
    AND destination = house_id_val::text 
    AND timestamp >= start_date_val 
    AND timestamp <= end_date_val;

  RETURN invested_amount_val;
END;
$$;

ALTER FUNCTION "public"."get_total_investments"("house_id_val" integer, "user_name" "text", "start_date_val" "date", "end_date_val" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_total_profits"("h_id" integer, "username" "text" DEFAULT "public"."get_username"("auth"."uid"()), "start_date" "date" DEFAULT '1900-02-08'::"date", "end_date" "date" DEFAULT '2900-02-08'::"date", OUT "houseid" integer, OUT "my_profits" numeric, OUT "network_profits" numeric) RETURNS "record"
    LANGUAGE "plpgsql"
    AS $$
DECLARE 
  my_profits_val NUMERIC := 0;
  network_profits_val NUMERIC := 0;
  booking_ids text[];
BEGIN
  SELECT ARRAY(
    SELECT b.id::text
    FROM bookings b
    WHERE b.house_id = h_id
  ) INTO booking_ids;

  SELECT COALESCE(SUM(t.amount), 0) INTO my_profits_val
  FROM transactions t
  WHERE t.source = ANY(booking_ids)
    AND t.destination = username
    AND t.timestamp BETWEEN start_date AND end_date;

  SELECT COALESCE(SUM(t.amount), 0) INTO network_profits_val
  FROM transactions t
  WHERE t.source = ANY(booking_ids)
    AND t.destination != username
    AND t.timestamp BETWEEN start_date AND end_date;

  houseId := h_id;
  my_profits := my_profits_val;
  network_profits := network_profits_val;
END;
$$;

ALTER FUNCTION "public"."get_total_profits"("h_id" integer, "username" "text", "start_date" "date", "end_date" "date", OUT "houseid" integer, OUT "my_profits" numeric, OUT "network_profits" numeric) OWNER TO "postgres";

CREATE FUNCTION "public"."get_transaction_label"("source" "text", "destination" "text") RETURNS TABLE("icon" "text", "title" "text", "amount_color" "text")
    LANGUAGE "plpgsql"
    AS $_$
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
$_$;

ALTER FUNCTION "public"."get_transaction_label"("source" "text", "destination" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."get_transactions"("start_date" "date" DEFAULT '1900-02-08'::"date", "end_date" "date" DEFAULT '2900-02-08'::"date") RETURNS TABLE("id" integer, "timestampts" timestamp with time zone, "source" character varying, "destination" character varying, "amount" "text", "icon" "text", "title" "text", "amount_color" "text", "transaction_timeframe" "text")
    LANGUAGE "plpgsql"
    AS $$
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
$$;

ALTER FUNCTION "public"."get_transactions"("start_date" "date", "end_date" "date") OWNER TO "postgres";

CREATE FUNCTION "public"."get_unread_notifications_count"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  user_created_at TIMESTAMPTZ;
  unread_count INTEGER;
BEGIN
  -- Get the creation timestamp of the user
  SELECT subscribed_at INTO user_created_at FROM referrals r WHERE r.username = get_username(auth.uid());

  -- Calculate the count of unread notifications
  SELECT COUNT(*)
  INTO unread_count
  FROM notifications n
  WHERE (get_username(auth.uid()) = ANY(n.usernames) OR n.usernames IS NULL)
    AND (get_username(auth.uid()) NOT IN (SELECT unnest(n.read)))
    AND (n.date >= user_created_at);

  RETURN unread_count;
END;
$$;

ALTER FUNCTION "public"."get_unread_notifications_count"() OWNER TO "postgres";

CREATE FUNCTION "public"."get_week_profits"() RETURNS TABLE("labels" "text"[], "amounts" numeric[])
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  booking_ids text[];
  week_start_date date DEFAULT (date_trunc('week', (CURRENT_DATE)::timestamp with time zone))::date;
  week_end_date date DEFAULT ((date_trunc('week', (CURRENT_DATE)::timestamp with time zone) + '6 days'::interval))::date;
  profits_arr numeric[];
BEGIN
  SELECT array_agg(id::text) INTO booking_ids
  FROM bookings;

  profits_arr := ARRAY(
    SELECT COALESCE(SUM(transactions.amount), 0) AS profit
    FROM transactions
    JOIN bookings ON bookings.id::text = transactions.source
    WHERE transactions.destination = get_username(auth.uid())
      AND transactions.timestamp::date BETWEEN week_start_date AND week_end_date
      AND bookings.id::text = ANY (booking_ids)
    GROUP BY transactions.timestamp::date
    ORDER BY transactions.timestamp::date
  );

  labels := ARRAY(
    SELECT to_char(day, 'Day')
    FROM unnest(generate_series(week_start_date, week_end_date, '1 day'::interval)::date) AS day
  );

  amounts := profits_arr;

  RETURN NEXT;
END;
$$;

ALTER FUNCTION "public"."get_week_profits"() OWNER TO "postgres";

CREATE FUNCTION "public"."increase_user_balance"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

BEGIN
  IF (NEW.destination !~ '^[0-9]+$' AND length(NEW.destination) < 20) THEN
    UPDATE Profiles
    SET balance = balance + NEW.amount
    WHERE username = NEW.destination;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."increase_user_balance"() OWNER TO "postgres";

CREATE FUNCTION "public"."increment_first_line"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
    UPDATE public.profiles SET first_line = first_line + 1 WHERE username = NEW.invited_by;
    RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."increment_first_line"() OWNER TO "postgres";

CREATE FUNCTION "public"."increment_second_line"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
    UPDATE public.profiles SET second_line = second_line + 1 WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.invited_by);
    RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."increment_second_line"() OWNER TO "postgres";

CREATE FUNCTION "public"."increment_third_line"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
    UPDATE public.profiles SET third_line = third_line + 1 WHERE username = (SELECT invited_by FROM public.referrals WHERE username = (SELECT invited_by FROM public.referrals WHERE username = NEW.invited_by));
    RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."increment_third_line"() OWNER TO "postgres";

CREATE FUNCTION "public"."insert_referral_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  INSERT INTO public.referrals (username, invited_by)
  VALUES (NEW.username, NEW.invited_by);
  RETURN NULL;
END;

$$;

ALTER FUNCTION "public"."insert_referral_func"() OWNER TO "postgres";

CREATE FUNCTION "public"."is_booking_from_house"("booking_id" integer, "house_booking_id" integer) RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM bookings WHERE id = booking_id AND house_id = house_booking_id);
END;
$$;

ALTER FUNCTION "public"."is_booking_from_house"("booking_id" integer, "house_booking_id" integer) OWNER TO "postgres";

CREATE FUNCTION "public"."limit_inviter"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  invite_limit INT;
BEGIN

  SELECT invite_limits INTO invite_limit
  FROM public.profiles
  WHERE username = NEW.invited_by;
  
  IF invite_limit IS NOT NULL AND (
      SELECT COUNT(*) FROM public.referrals WHERE invited_by = NEW.invited_by
    ) >= invite_limit
  THEN
    RAISE EXCEPTION '% has sent out too many invites', NEW.invited_by;
  END IF;

  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."limit_inviter"() OWNER TO "postgres";

CREATE FUNCTION "public"."new_citizen_notification"("invited_by" "text", "username" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public.notifications (usernames, title, message, image, link, icon)
  VALUES ( ARRAY[invited_by], 'New Citizen In The Network',
    CONCAT(INITCAP(username)) || ' subscribed thanks to you!', public.get_avatar(username), username, 'network');
END;
$$;

ALTER FUNCTION "public"."new_citizen_notification"("invited_by" "text", "username" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."notiffications_promote_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  second_line_inviter_username VARCHAR(255);
  referral_amount DECIMAL(10,2);

  begin
    perform private.promote_notiffications(NEW.id);
    return NULL;
  end;
  

$$;

ALTER FUNCTION "public"."notiffications_promote_trigger"() OWNER TO "postgres";

CREATE FUNCTION "public"."notify_andreafuturi"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  IF NEW.source = get_username(auth.uid()) AND LENGTH(NEW.destination) > 20 THEN
    INSERT INTO Notifications (usernames, title, message, value, link, color, image)
    VALUES ('{andreafuturi}', 'New withdrawal', 'New withdrawal by '||get_username(auth.uid())||' !', NEW.amount, get_username(auth.uid()), 'info', 'withdraw');
  END IF;

  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."notify_andreafuturi"() OWNER TO "postgres";

CREATE FUNCTION "public"."notify_rank_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
    IF NEW.ranking != OLD.ranking THEN
        INSERT INTO Notifications (usernames, title, message,link, icon,image)
        VALUES (ARRAY[NEW.username], 'Level Up!', 'Congratulations you turned into a ' || NEW.ranking || '!' , NEW.username, 'upgrade',public.get_avatar(NEW.username));
    END IF;
    RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."notify_rank_change"() OWNER TO "postgres";

CREATE FUNCTION "public"."notify_rank_change_network"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  IF OLD.ranking != NEW.ranking THEN
    INSERT INTO Notifications(usernames, title, message, image, link,icon,platform)
    VALUES (
      (SELECT array_agg(username) FROM Referrals WHERE username = NEW.invited_by OR invited_by = NEW.username),
      'New '||NEW.ranking||' In The Network',
        COALESCE( INITCAP(NEW.display_name), INITCAP(NEW.username))||' turned into a '||NEW.ranking||'!',
      public.get_avatar(NEW.username), NEW.username,'level',ARRAY['in-app']
    );
  END IF;
  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."notify_rank_change_network"() OWNER TO "postgres";

CREATE FUNCTION "public"."notify_wallet_verification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
    IF NEW.is_verified = TRUE AND OLD.is_verified = FALSE THEN
        INSERT INTO Notifications (usernames, title, message, link,icon,image)
        VALUES (ARRAY[NEW.owned_by], 'New Wallet Linked', 'Your wallet has been verified!', 'settings' ,'verified','verified');
    END IF;
    RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."notify_wallet_verification"() OWNER TO "postgres";

CREATE FUNCTION "public"."reset_db"("delete_users" boolean DEFAULT false) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$

DECLARE
    keep_users text[] := ARRAY['tester'];
BEGIN
    DELETE FROM public.bookings;
    DELETE FROM public.wallets;
    DELETE FROM public.transactions;
    DELETE FROM public.notifications;

    UPDATE public.profiles
    SET total_profits = 0,
        total_investments = 0,
        balance = 5000;

    UPDATE public.houses
    SET amount_reached = 0,
        investors = '{}',
        is_paid = FALSE,
        is_ready = FALSE;

    IF delete_users THEN
        DELETE FROM storage.objects WHERE  bucket_id= 'avatar' AND name NOT IN(SELECT unnest(keep_users));
        DELETE FROM public.profiles WHERE username NOT IN (SELECT unnest(keep_users));     
        DELETE FROM public.referrals WHERE username NOT IN (SELECT unnest(keep_users)); 
        DELETE FROM auth.users WHERE id NOT IN (SELECT id FROM public.profiles WHERE username IN (SELECT unnest(keep_users)));

    END IF;  

    RETURN;
END;

$$;

ALTER FUNCTION "public"."reset_db"("delete_users" boolean) OWNER TO "postgres";

CREATE FUNCTION "public"."send_apartament_ownership_ended_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN

 INSERT INTO Notifications (usernames, title, message, image,link,icon)
    VALUES (NEW.investors, 'Apartament`s Ownership Ended','Click here to check performance of '|| NEW.name, NEW.images[1], 'investment/' || NEW.id,'performance');
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."send_apartament_ownership_ended_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."send_booking_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$DECLARE
  house_images VARCHAR(255)[];
  house_image VARCHAR(255);
  nights INT;
  value DECIMAL(10,2);
  total INT;
  house_name VARCHAR(255);
  night_plural TEXT; -- Added variable for pluralization
BEGIN
  SELECT images, name, total_required INTO house_images, house_name, total FROM Houses WHERE id = NEW.house_id;
  nights := DATE_PART('day', NEW.end_date - NEW.start_date);
  house_image := house_images[1];
  
  -- Determine pluralization for 'night(s)'
  IF nights = 1 THEN
    night_plural := 'night';
  ELSE
    night_plural := 'nights';
  END IF;
  
  INSERT INTO Notifications (usernames, title, message, value, image, link, icon, color)
    SELECT ARRAY[unnest.investor], 'Apartment Booked', house_name || ' has been booked for ' || nights || ' ' || night_plural || '!', (SUM(amount) / total) * NEW.income, house_images[1], 'investment/' || NEW.house_id, 'profit', 'success'
    FROM (SELECT unnest(investors) as investor FROM houses WHERE id = NEW.house_id) as unnest
    JOIN Transactions ON unnest.investor = Transactions.source and Transactions.destination = NEW.house_id::text
    GROUP BY unnest.investor;
  RETURN NULL;
END;$$;

ALTER FUNCTION "public"."send_booking_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."send_investment_almostcomplete_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO Notifications (usernames, title, message, image, link, icon, color)
    VALUES (NEW.investors, 'Investment Almost Completed', 'Only ' || (NEW.total_required - NEW.amount_reached) || ' USDT to unlock ' || NEW.name || '’s profits!', NEW.images[1], 'investment/' || NEW.id, 'almost', 'info');
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."send_investment_almostcomplete_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."send_investment_completed_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
 INSERT INTO Notifications (usernames, title, message, image,link,icon,color)
    VALUES (NEW.investors, 'Investment Completed!', NEW.name || ' will soon be available in Airbnb!', NEW.images[1], 'investment/' || NEW.id,'party','success');

  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."send_investment_completed_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."send_new_apartment_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO Notifications (title, message, image, link, icon)
  VALUES ('New Apartment Available', NEW.name || ' has been added to the market!', NEW.images[1], 'investment/' || NEW.id, 'market');
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."send_new_apartment_notification"() OWNER TO "postgres";

CREATE FUNCTION "public"."update_amount_reached"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

BEGIN
  IF (NEW.destination ~ '^[0-9]+$') THEN
    UPDATE Houses
    SET amount_reached = amount_reached + NEW.amount
    WHERE id = (NEW.destination)::integer;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."update_amount_reached"() OWNER TO "postgres";

CREATE FUNCTION "public"."update_house_investors"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    IF (NEW.destination ~ '^[0-9]+$') THEN
        -- Check if the source value is already in the investors array
        IF NOT (NEW.source = ANY(SELECT unnest(investors) FROM houses WHERE id = NEW.destination::integer)) THEN
            -- Append the source value to the investors array
            UPDATE houses SET investors = array_append(investors, NEW.source) WHERE id = NEW.destination::integer;
        END IF;
    END IF;

    RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."update_house_investors"() OWNER TO "postgres";

CREATE FUNCTION "public"."update_profiles_email"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

BEGIN
  IF NEW.email <> OLD.email THEN
    UPDATE profiles
    SET email = NEW.email
     WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."update_profiles_email"() OWNER TO "postgres";

CREATE FUNCTION "public"."update_total_investment"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

BEGIN
    IF (NEW.destination ~ '^[0-9]+$') THEN
        UPDATE profiles SET total_investments = total_investments + NEW.amount WHERE username = NEW.source;
    END IF;
    RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."update_total_investment"() OWNER TO "postgres";

CREATE FUNCTION "public"."update_user_password"("user_id" "uuid", "new_password" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE id = user_id;
END;
$$;

ALTER FUNCTION "public"."update_user_password"("user_id" "uuid", "new_password" "text") OWNER TO "postgres";

CREATE FUNCTION "public"."update_user_profits"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$

BEGIN
  IF (NEW.destination !~ '^[0-9]+$' AND length(NEW.destination) < 20 ) THEN
    UPDATE Profiles
    SET total_profits = total_profits + NEW.amount
    WHERE username = NEW.destination;
  END IF;
  RETURN NEW;
END;

$_$;

ALTER FUNCTION "public"."update_user_profits"() OWNER TO "postgres";

CREATE FUNCTION "public"."validate_transaction_amount"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$

DECLARE
  remaining_amount NUMERIC;
BEGIN
  IF NEW.source =  get_username(auth.uid())  AND EXISTS (
SELECT 1 FROM houses WHERE id::text = NEW.destination
  ) THEN
    SELECT total_required - COALESCE(get_invested_amount(id),0) INTO remaining_amount
    FROM houses
    WHERE id = CAST(NEW.destination AS INTEGER);

    IF NEW.amount > remaining_amount THEN
      RAISE EXCEPTION 'Transaction amount exceeds missing amount for the destination house';
    END IF;
  END IF;

  RETURN NEW;
END;

$$;

ALTER FUNCTION "public"."validate_transaction_amount"() OWNER TO "postgres";

CREATE FUNCTION "public"."verify_password"("entered_password" "text", "stored_hash" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Compare the hashed entered_password with the stored_hash
  RETURN crypt(entered_password, stored_hash) = stored_hash;
END;
$$;

ALTER FUNCTION "public"."verify_password"("entered_password" "text", "stored_hash" "text") OWNER TO "postgres";

CREATE TABLE "internal"."email_templates" (
    "id" bigint NOT NULL,
    "subject" "text",
    "content" "text",
    "email_language" "text",
    "email_type" "text"
);

ALTER TABLE "internal"."email_templates" OWNER TO "postgres";

ALTER TABLE "internal"."email_templates" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "internal"."email_templates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE "public"."bookings" (
    "id" integer NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "income" numeric(10,2) NOT NULL,
    "house_id" integer NOT NULL,
    "guests" smallint DEFAULT '1'::smallint NOT NULL,
    "received" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text"),
    CONSTRAINT "end_date_after_start_date" CHECK (("start_date" < "end_date"))
);

ALTER TABLE "public"."bookings" OWNER TO "postgres";

ALTER TABLE "public"."bookings" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."bookings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE "public"."houses" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."houses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE "public"."log" (
    "username" character varying NOT NULL,
    "last_access" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."log" OWNER TO "postgres";

CREATE TABLE "public"."notifications" (
    "id" integer NOT NULL,
    "usernames" "text"[],
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "image" "text",
    "read" "text"[],
    "value" numeric(10,2),
    "link" "text",
    "icon" "text",
    "color" "text",
    "platform" "text"[]
);

ALTER TABLE "public"."notifications" OWNER TO "postgres";

CREATE SEQUENCE "public"."notifications_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE "public"."notifications_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."notifications_id_seq" OWNED BY "public"."notifications"."id";

CREATE TABLE "public"."profiles" (
    "username" "text" NOT NULL,
    "display_name" "text",
    "balance" numeric DEFAULT '5000'::numeric NOT NULL,
    "ranking" "text" DEFAULT 'Citizen'::"text" NOT NULL,
    "public_profile" boolean DEFAULT true NOT NULL,
    "total_investments" real DEFAULT '0'::real NOT NULL,
    "total_profits" real DEFAULT '0'::real NOT NULL,
    "first_line" integer DEFAULT 0 NOT NULL,
    "second_line" integer DEFAULT 0 NOT NULL,
    "third_line" integer DEFAULT 0 NOT NULL,
    "invited_by" "text",
    "email" "text" DEFAULT ''::"text" NOT NULL,
    "invite_limits" numeric DEFAULT '0'::numeric,
    "staff" "text",
    "confirmed_email" character varying,
    "phone" "text",
    CONSTRAINT "check_balance" CHECK (("balance" >= (0)::numeric)),
    CONSTRAINT "username_blacklist_constraint" CHECK (("username" <> ALL (ARRAY[('settings'::character varying)::"text", ('dashboard'::character varying)::"text", ('login'::character varying)::"text", ('register'::character varying)::"text", ('recap'::character varying)::"text", ('investments'::character varying)::"text", ('profits'::character varying)::"text", ('network'::character varying)::"text", ('feed'::character varying)::"text", ('market'::character varying)::"text", ('balance'::character varying)::"text", ('addwallet'::character varying)::"text"]))),
    CONSTRAINT "username_constraint" CHECK (("length"("username") < 20))
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

CREATE VIEW "public"."profiles_view" AS
 SELECT "profiles"."username",
    "profiles"."email",
    "profiles"."ranking",
    "profiles"."display_name",
    "profiles"."public_profile",
    "profiles"."invited_by",
    "profiles"."staff"
   FROM "public"."profiles";

ALTER TABLE "public"."profiles_view" OWNER TO "postgres";

CREATE TABLE "public"."ranking" (
    "name" "text" NOT NULL,
    "first_line_rate" numeric NOT NULL,
    "second_line_rate" numeric NOT NULL,
    "third_line_rate" numeric NOT NULL,
    "level" numeric
);

ALTER TABLE "public"."ranking" OWNER TO "postgres";

CREATE TABLE "public"."referrals" (
    "username" "text" NOT NULL,
    "invited_by" "text",
    "subscribed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."referrals" OWNER TO "postgres";

CREATE TABLE "public"."transactions" (
    "id" integer NOT NULL,
    "source" character varying(255) DEFAULT "public"."get_username"("auth"."uid"()) NOT NULL,
    "destination" character varying(255) NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "timestamp" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'completed'::"text",
    CONSTRAINT "positive_amount_allowed" CHECK (("amount" > (0)::numeric))
);

ALTER TABLE "public"."transactions" OWNER TO "postgres";

CREATE SEQUENCE "public"."transactions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE "public"."transactions_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."transactions_id_seq" OWNED BY "public"."transactions"."id";

CREATE TABLE "public"."wallets" (
    "address" "text" NOT NULL,
    "wallet_name" "text" NOT NULL,
    "owned_by" "text" NOT NULL,
    "is_verified" boolean DEFAULT false NOT NULL,
    "blockchain" "text" NOT NULL,
    CONSTRAINT "wallet_constraint" CHECK (("length"("address") > 20))
);

ALTER TABLE "public"."wallets" OWNER TO "postgres";

ALTER TABLE ONLY "public"."notifications" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."notifications_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."transactions_id_seq"'::"regclass");

ALTER TABLE ONLY "internal"."email_templates"
    ADD CONSTRAINT "email_templates_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."houses"
    ADD CONSTRAINT "houses_id_key" UNIQUE ("id");

ALTER TABLE ONLY "public"."houses"
    ADD CONSTRAINT "houses_name_key" UNIQUE ("name");

ALTER TABLE ONLY "public"."houses"
    ADD CONSTRAINT "houses_pkey" PRIMARY KEY ("id", "name");

ALTER TABLE ONLY "public"."log"
    ADD CONSTRAINT "log_pkey" PRIMARY KEY ("username");

ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");

ALTER TABLE ONLY "public"."ranking"
    ADD CONSTRAINT "ranking_pkey" PRIMARY KEY ("name");

ALTER TABLE ONLY "public"."referrals"
    ADD CONSTRAINT "referrals_pkey" PRIMARY KEY ("username");

ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("username");

ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_pkey" PRIMARY KEY ("address");

CREATE INDEX "houses_id_idx" ON "public"."houses" USING "btree" ("id");

CREATE INDEX "idx_invited_by" ON "public"."profiles" USING "btree" ("invited_by");

CREATE INDEX "transactions_destination_idx" ON "public"."transactions" USING "btree" ("destination");

CREATE INDEX "transactions_source_idx" ON "public"."transactions" USING "btree" ("source");

CREATE INDEX "users_name_idx" ON "public"."profiles" USING "btree" ("username");

CREATE INDEX "wallets_owned_by_idx" ON "public"."wallets" USING "btree" ("owned_by");

CREATE TRIGGER "apartament_ownership_ended_trigger" AFTER UPDATE ON "public"."houses" FOR EACH ROW WHEN ((("new"."contract_ended" = true) AND ("old"."contract_ended" = false))) EXECUTE FUNCTION "public"."send_apartament_ownership_ended_notification"();

CREATE TRIGGER "check_transaction_amount" BEFORE INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."validate_transaction_amount"();

CREATE TRIGGER "create_new_citizen_notification" AFTER INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."create_new_citizen_notification"();

ALTER TABLE "public"."profiles" DISABLE TRIGGER "create_new_citizen_notification";

CREATE TRIGGER "create_referral_notification" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."create_referral_notification"();

CREATE TRIGGER "create_referral_transaction" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."create_referral_transaction"();

CREATE TRIGGER "create_second_line_referral_transaction" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."create_second_line_referral_transaction"();

ALTER TABLE "public"."transactions" DISABLE TRIGGER "create_second_line_referral_transaction";

CREATE TRIGGER "create_third_line_referral_transaction" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."create_third_line_referral_transaction"();

ALTER TABLE "public"."transactions" DISABLE TRIGGER "create_third_line_referral_transaction";

CREATE TRIGGER "decrease_user_balance" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."decrease_user_balance"();

CREATE TRIGGER "delete_referral" AFTER DELETE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."delete_referral_func"();

CREATE TRIGGER "deposit_notification_trigger" AFTER INSERT ON "public"."transactions" FOR EACH ROW WHEN ((("length"(("new"."source")::"text") > 20) AND ("length"(("new"."destination")::"text") < 20))) EXECUTE FUNCTION "public"."deposit_notification"();

CREATE TRIGGER "distribute_income_to_investors" AFTER INSERT ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."distribute_income_to_investors_func"();

CREATE TRIGGER "house_ready_notification" AFTER UPDATE ON "public"."houses" FOR EACH ROW WHEN ((("new"."is_ready" = true) AND ("old"."is_ready" = false))) EXECUTE FUNCTION "public"."create_house_ready_notification"();

CREATE TRIGGER "increase_user_balance" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."increase_user_balance"();

CREATE TRIGGER "increment_first_line_trigger" AFTER INSERT ON "public"."referrals" FOR EACH ROW EXECUTE FUNCTION "public"."increment_first_line"();

CREATE TRIGGER "increment_second_line_trigger" AFTER INSERT ON "public"."referrals" FOR EACH ROW EXECUTE FUNCTION "public"."increment_second_line"();

CREATE TRIGGER "increment_third_line_trigger" AFTER INSERT ON "public"."referrals" FOR EACH ROW EXECUTE FUNCTION "public"."increment_third_line"();

CREATE TRIGGER "insert_referral" AFTER INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."insert_referral_func"();

CREATE TRIGGER "investment_almostcomplete_notification" AFTER UPDATE ON "public"."houses" FOR EACH ROW WHEN ((("new"."amount_reached" < "new"."total_required") AND ("new"."amount_reached" >= (0.9 * "new"."total_required")) AND ("old"."amount_reached" < (0.9 * "new"."total_required")))) EXECUTE FUNCTION "public"."send_investment_almostcomplete_notification"();

CREATE TRIGGER "limit_inviter_trigger" BEFORE INSERT ON "public"."referrals" FOR EACH ROW EXECUTE FUNCTION "public"."limit_inviter"();

CREATE TRIGGER "notify_andreafuturi" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."notify_andreafuturi"();

CREATE TRIGGER "notify_rank_change" AFTER UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."notify_rank_change"();

CREATE TRIGGER "notify_rank_change_network" AFTER UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."notify_rank_change_network"();

CREATE TRIGGER "notify_wallet_verification_trigger" AFTER UPDATE ON "public"."wallets" FOR EACH ROW EXECUTE FUNCTION "public"."notify_wallet_verification"();

CREATE TRIGGER "send_booking_notification" AFTER INSERT ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."send_booking_notification"();

CREATE TRIGGER "send_investment_completed_notification" AFTER UPDATE OF "amount_reached" ON "public"."houses" FOR EACH ROW WHEN ((("new"."amount_reached" >= "new"."total_required") AND ("old"."amount_reached" < "new"."total_required"))) EXECUTE FUNCTION "public"."send_investment_completed_notification"();

CREATE TRIGGER "send_new_apartment_notification" AFTER INSERT ON "public"."houses" FOR EACH ROW EXECUTE FUNCTION "public"."send_new_apartment_notification"();

CREATE TRIGGER "update_amount_reached" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_amount_reached"();

CREATE TRIGGER "update_house_investors" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_house_investors"();

CREATE TRIGGER "update_total_investment_trigger" AFTER INSERT OR UPDATE OF "destination" ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_total_investment"();

CREATE TRIGGER "update_user_profits" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_user_profits"();

ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_house_id_fkey" FOREIGN KEY ("house_id") REFERENCES "public"."houses"("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_confirmed_email_constraint" FOREIGN KEY ("confirmed_email") REFERENCES "auth"."users"("email");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "public"."profiles"("username");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_phone_fkey" FOREIGN KEY ("phone") REFERENCES "auth"."users"("phone");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_ranking_fkey" FOREIGN KEY ("ranking") REFERENCES "public"."ranking"("name");

ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_owned_by_fkey" FOREIGN KEY ("owned_by") REFERENCES "public"."profiles"("username");

CREATE POLICY "Allow_referral_to_create_transactions" ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "profiles_1"."username"
   FROM "public"."profiles" "profiles_1"
  WHERE ("profiles_1"."username" = "profiles_1"."invited_by")) = ( SELECT "profiles_1"."username"
   FROM "public"."profiles" "profiles_1"
  WHERE ("profiles_1"."username" = "public"."get_username"("auth"."uid"())))));

CREATE POLICY "Enable delete for users based on owned_by" ON "public"."wallets" FOR DELETE TO "authenticated" USING (("public"."get_username"("auth"."uid"()) = "owned_by"));

CREATE POLICY "Enable insert for authenticated users only" ON "public"."bookings" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."houses" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."referrals" FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable insert for registration" ON "public"."profiles" FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable own update access for authenticated users" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));

CREATE POLICY "Enable select for authenticated users only" ON "public"."bookings" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable select for authenticated users only" ON "public"."houses" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable update for wallets owned by logged in user" ON "public"."wallets" FOR UPDATE TO "authenticated" USING (("public"."get_username"("auth"."uid"()) = "owned_by")) WITH CHECK (("public"."get_username"("auth"."uid"()) = "owned_by"));

ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."houses" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "insert_notifications_policy" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));

CREATE POLICY "insert_specific_transactions_policy" ON "public"."transactions" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));

CREATE POLICY "insert_specific_wallets_policy" ON "public"."wallets" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));

ALTER TABLE "public"."log" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."ranking" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."referrals" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "select_notifications_policy" ON "public"."notifications" FOR SELECT TO "authenticated" USING (((("auth"."uid"() IS NOT NULL) AND ("public"."get_username"("auth"."uid"()) = ANY ("usernames"))) OR ("usernames" IS NULL)));

CREATE POLICY "select_own_profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

CREATE POLICY "select_specific_ranking_policy" ON "public"."ranking" FOR SELECT TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

CREATE POLICY "select_specific_referrals_policy" ON "public"."referrals" FOR SELECT TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

CREATE POLICY "select_specific_wallets_policy" ON "public"."wallets" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND ("public"."get_username"("auth"."uid"()) = ANY (ARRAY["owned_by"]))));

ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transactions_select_policy" ON "public"."transactions" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "update_houses_policy" ON "public"."houses" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

CREATE POLICY "update_notifications_policy" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

CREATE POLICY "update_specific_transactions_policy" ON "public"."transactions" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IS NOT NULL));

ALTER TABLE "public"."wallets" ENABLE ROW LEVEL SECURITY;

REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT ALL ON SCHEMA "public" TO PUBLIC;

GRANT ALL ON FUNCTION "public"."airbnb_link_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."airbnb_link_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."airbnb_link_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."check_notification_update_policy"("username" "text", "user_names" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."check_notification_update_policy"("username" "text", "user_names" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_notification_update_policy"("username" "text", "user_names" "text"[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."count_bookings"("house_id_param" integer, "start_date_param" "date", "end_date_param" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."count_bookings"("house_id_param" integer, "start_date_param" "date", "end_date_param" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_bookings"("house_id_param" integer, "start_date_param" "date", "end_date_param" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_username"("uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_username"("uid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_username"("uid" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."count_properties"("username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."count_properties"("username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_properties"("username" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_house_ready_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_house_ready_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_house_ready_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_investing_transaction"("new_destination" "text", "new_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_investing_transaction"("new_destination" "text", "new_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_investing_transaction"("new_destination" "text", "new_amount" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_new_citizen_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_new_citizen_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_new_citizen_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_profile_for_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_profile_for_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_profile_for_new_user"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_referral_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_referral_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_referral_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_referral_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_referral_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_referral_transaction"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_second_line_referral_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_second_line_referral_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_second_line_referral_transaction"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_third_line_referral_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_third_line_referral_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_third_line_referral_transaction"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_widthdraw_transaction"("new_destination" "text", "new_amount" numeric, "new_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_widthdraw_transaction"("new_destination" "text", "new_amount" numeric, "new_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_widthdraw_transaction"("new_destination" "text", "new_amount" numeric, "new_status" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."decrease_user_balance"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrease_user_balance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrease_user_balance"() TO "service_role";

GRANT ALL ON FUNCTION "public"."delete_referral_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_referral_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_referral_func"() TO "service_role";

GRANT ALL ON FUNCTION "public"."deposit_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."deposit_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."deposit_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."distribute_income_to_investors_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."distribute_income_to_investors_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."distribute_income_to_investors_func"() TO "service_role";

GRANT ALL ON TABLE "public"."houses" TO "anon";
GRANT ALL ON TABLE "public"."houses" TO "authenticated";
GRANT ALL ON TABLE "public"."houses" TO "service_role";

GRANT ALL ON FUNCTION "public"."get_active_investments"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_investments"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_investments"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_all_bookings"("house_booking_id_param" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_bookings"("house_booking_id_param" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_bookings"("house_booking_id_param" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_all_houses_profits"("username" "text", "start_date" "date", "end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_houses_profits"("username" "text", "start_date" "date", "end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_houses_profits"("username" "text", "start_date" "date", "end_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_almost_completed"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_almost_completed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_almost_completed"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_avatar"("user_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_avatar"("user_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_avatar"("user_name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_balance_page"(OUT "balance" numeric, OUT "wallet_data" "json") TO "anon";
GRANT ALL ON FUNCTION "public"."get_balance_page"(OUT "balance" numeric, OUT "wallet_data" "json") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_balance_page"(OUT "balance" numeric, OUT "wallet_data" "json") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_booked_days"("houseid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_booked_days"("houseid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_booked_days"("houseid" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_completed_properties"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_completed_properties"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_completed_properties"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_contest_leaderboard"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_contest_leaderboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_contest_leaderboard"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_dashboard_page"(OUT "my_investments" numeric, OUT "investment_increase" numeric, OUT "my_profits" numeric, OUT "profits_increase" numeric, OUT "my_network" integer, OUT "network_increase" numeric, OUT "almost_completed" "json", OUT "amount" numeric[], OUT "this_day_profits" numeric, OUT "new_houses" "json") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dashboard_page"(OUT "my_investments" numeric, OUT "investment_increase" numeric, OUT "my_profits" numeric, OUT "profits_increase" numeric, OUT "my_network" integer, OUT "network_increase" numeric, OUT "almost_completed" "json", OUT "amount" numeric[], OUT "this_day_profits" numeric, OUT "new_houses" "json") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dashboard_page"(OUT "my_investments" numeric, OUT "investment_increase" numeric, OUT "my_profits" numeric, OUT "profits_increase" numeric, OUT "my_network" integer, OUT "network_increase" numeric, OUT "almost_completed" "json", OUT "amount" numeric[], OUT "this_day_profits" numeric, OUT "new_houses" "json") TO "service_role";

REVOKE ALL ON FUNCTION "public"."get_email_template"("template_type" "text", "link" "text", "language" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_email_template"("template_type" "text", "link" "text", "language" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_house_from_booking"("booking_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_house_from_booking"("booking_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_house_from_booking"("booking_id" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_house_name"("house_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_house_name"("house_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_house_name"("house_id" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_invested_amount"("houseid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_invested_amount"("houseid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_invested_amount"("houseid" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_investment"("uid" "uuid", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_investment"("uid" "uuid", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_investment"("uid" "uuid", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_investment_page"("h_id" integer, OUT "title" "text", OUT "pic" "text"[], OUT "location" "text", OUT "duration" integer, OUT "price" numeric, OUT "description" "text", OUT "my_investment" numeric, OUT "network_investments" numeric, OUT "missing_investments" numeric, OUT "total_required" numeric, OUT "my_profits" numeric, OUT "network_profits" numeric, OUT "top_investors" "json", OUT "similar_houses" "json", OUT "is_ready" boolean, OUT "is_investor" boolean, OUT "current_roi" numeric, OUT "current_roi_percentage" numeric, OUT "bookings" numeric, OUT "total_days_passed" numeric, OUT "occupancy_rate" numeric, OUT "missing_time" numeric, OUT "investment_details" "json", OUT "daily_investment_cost" numeric, OUT "investment_used_now" numeric, OUT "total_contract_days" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_investment_page"("h_id" integer, OUT "title" "text", OUT "pic" "text"[], OUT "location" "text", OUT "duration" integer, OUT "price" numeric, OUT "description" "text", OUT "my_investment" numeric, OUT "network_investments" numeric, OUT "missing_investments" numeric, OUT "total_required" numeric, OUT "my_profits" numeric, OUT "network_profits" numeric, OUT "top_investors" "json", OUT "similar_houses" "json", OUT "is_ready" boolean, OUT "is_investor" boolean, OUT "current_roi" numeric, OUT "current_roi_percentage" numeric, OUT "bookings" numeric, OUT "total_days_passed" numeric, OUT "occupancy_rate" numeric, OUT "missing_time" numeric, OUT "investment_details" "json", OUT "daily_investment_cost" numeric, OUT "investment_used_now" numeric, OUT "total_contract_days" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_investment_page"("h_id" integer, OUT "title" "text", OUT "pic" "text"[], OUT "location" "text", OUT "duration" integer, OUT "price" numeric, OUT "description" "text", OUT "my_investment" numeric, OUT "network_investments" numeric, OUT "missing_investments" numeric, OUT "total_required" numeric, OUT "my_profits" numeric, OUT "network_profits" numeric, OUT "top_investors" "json", OUT "similar_houses" "json", OUT "is_ready" boolean, OUT "is_investor" boolean, OUT "current_roi" numeric, OUT "current_roi_percentage" numeric, OUT "bookings" numeric, OUT "total_days_passed" numeric, OUT "occupancy_rate" numeric, OUT "missing_time" numeric, OUT "investment_details" "json", OUT "daily_investment_cost" numeric, OUT "investment_used_now" numeric, OUT "total_contract_days" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_investments_page"(OUT "total_investments" numeric, OUT "active_investments" numeric, OUT "locked_investments" numeric, OUT "completed_investments" numeric, OUT "total_properties" numeric, OUT "active_properties" numeric, OUT "locked_properties" numeric, OUT "completed_properties" numeric, OUT "my_properties" "json", OUT "amounts" numeric[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_investments_page"(OUT "total_investments" numeric, OUT "active_investments" numeric, OUT "locked_investments" numeric, OUT "completed_investments" numeric, OUT "total_properties" numeric, OUT "active_properties" numeric, OUT "locked_properties" numeric, OUT "completed_properties" numeric, OUT "my_properties" "json", OUT "amounts" numeric[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_investments_page"(OUT "total_investments" numeric, OUT "active_investments" numeric, OUT "locked_investments" numeric, OUT "completed_investments" numeric, OUT "total_properties" numeric, OUT "active_properties" numeric, OUT "locked_properties" numeric, OUT "completed_properties" numeric, OUT "my_properties" "json", OUT "amounts" numeric[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_invited_users"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_invited_users"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_invited_users"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_last_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_last_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_last_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_locked_investments"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_locked_investments"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_locked_investments"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_market"("start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_market"("start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market"("start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_network"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_network"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_network"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_network_investment"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_network_investment"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_network_investment"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_network_lines_investment"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_network_lines_investment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_network_lines_investment"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_network_page"(OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_line_network" numeric, OUT "total_investments" numeric, OUT "first_line_investments" numeric, OUT "second_line_investments" numeric, OUT "other_line_investments" numeric, OUT "my_network" "json", OUT "amount" numeric[], OUT "limits_left" integer, OUT "referral_profit_rate" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_network_page"(OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_line_network" numeric, OUT "total_investments" numeric, OUT "first_line_investments" numeric, OUT "second_line_investments" numeric, OUT "other_line_investments" numeric, OUT "my_network" "json", OUT "amount" numeric[], OUT "limits_left" integer, OUT "referral_profit_rate" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_network_page"(OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_line_network" numeric, OUT "total_investments" numeric, OUT "first_line_investments" numeric, OUT "second_line_investments" numeric, OUT "other_line_investments" numeric, OUT "my_network" "json", OUT "amount" numeric[], OUT "limits_left" integer, OUT "referral_profit_rate" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_network_table"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_network_table"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_network_table"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_networker_table"("username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_networker_table"("username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_networker_table"("username" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_new_houses"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_new_houses"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_new_houses"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_notifications"("start_date" "date", "end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_notifications"("start_date" "date", "end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_notifications"("start_date" "date", "end_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_past_investments"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_past_investments"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_past_investments"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_profile_page"("profile_username" "text", OUT "avatar" "text", OUT "display_name" "text", OUT "public_profile" boolean, OUT "top_investments" "json", OUT "networker_table" "json", OUT "last_investments" "json", OUT "usernames" "text"[], OUT "ranking" "text", OUT "days_since_signup" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_profile_page"("profile_username" "text", OUT "avatar" "text", OUT "display_name" "text", OUT "public_profile" boolean, OUT "top_investments" "json", OUT "networker_table" "json", OUT "last_investments" "json", OUT "usernames" "text"[], OUT "ranking" "text", OUT "days_since_signup" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profile_page"("profile_username" "text", OUT "avatar" "text", OUT "display_name" "text", OUT "public_profile" boolean, OUT "top_investments" "json", OUT "networker_table" "json", OUT "last_investments" "json", OUT "usernames" "text"[], OUT "ranking" "text", OUT "days_since_signup" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_profits_for_every_house"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_profits_for_every_house"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profits_for_every_house"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_profits_from_each_user_network"("start_date_val" "date", "end_date_val" "date", "name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_profits_from_each_user_network"("start_date_val" "date", "end_date_val" "date", "name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profits_from_each_user_network"("start_date_val" "date", "end_date_val" "date", "name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_profits_from_network_lines"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_profits_from_network_lines"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profits_from_network_lines"("name" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_profits_page"(OUT "total_properties_profits" numeric, OUT "six_month_contract_profit" numeric, OUT "twelve_month_contract_profit" numeric, OUT "life_time_contract_profit" numeric, OUT "total_bookings" numeric, OUT "six_month_contract_booking" numeric, OUT "twelve_month_contract_booking" numeric, OUT "life_time_contract_booking" numeric, OUT "total_network_profits" numeric, OUT "first_line_profits" numeric, OUT "second_line_profits" numeric, OUT "other_lines_profits" numeric, OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_lines_network" numeric, OUT "my_properties" "json", OUT "my_network" "json", OUT "amounts" numeric[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_profits_page"(OUT "total_properties_profits" numeric, OUT "six_month_contract_profit" numeric, OUT "twelve_month_contract_profit" numeric, OUT "life_time_contract_profit" numeric, OUT "total_bookings" numeric, OUT "six_month_contract_booking" numeric, OUT "twelve_month_contract_booking" numeric, OUT "life_time_contract_booking" numeric, OUT "total_network_profits" numeric, OUT "first_line_profits" numeric, OUT "second_line_profits" numeric, OUT "other_lines_profits" numeric, OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_lines_network" numeric, OUT "my_properties" "json", OUT "my_network" "json", OUT "amounts" numeric[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profits_page"(OUT "total_properties_profits" numeric, OUT "six_month_contract_profit" numeric, OUT "twelve_month_contract_profit" numeric, OUT "life_time_contract_profit" numeric, OUT "total_bookings" numeric, OUT "six_month_contract_booking" numeric, OUT "twelve_month_contract_booking" numeric, OUT "life_time_contract_booking" numeric, OUT "total_network_profits" numeric, OUT "first_line_profits" numeric, OUT "second_line_profits" numeric, OUT "other_lines_profits" numeric, OUT "total_network" numeric, OUT "first_line_network" numeric, OUT "second_line_network" numeric, OUT "other_lines_network" numeric, OUT "my_properties" "json", OUT "my_network" "json", OUT "amounts" numeric[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_properties"("start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_properties"("start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_properties"("start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_recent_houses"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_recent_houses"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_recent_houses"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_settings_page"(OUT "username" "text", OUT "display_name" "text", OUT "email" "text", OUT "phone" "text", OUT "email_change" character varying, OUT "confirmed_email" character varying, OUT "wallet_data" "json", OUT "profile_public" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_settings_page"(OUT "username" "text", OUT "display_name" "text", OUT "email" "text", OUT "phone" "text", OUT "email_change" character varying, OUT "confirmed_email" character varying, OUT "wallet_data" "json", OUT "profile_public" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_settings_page"(OUT "username" "text", OUT "display_name" "text", OUT "email" "text", OUT "phone" "text", OUT "email_change" character varying, OUT "confirmed_email" character varying, OUT "wallet_data" "json", OUT "profile_public" boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_similar_houses"("houseid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_similar_houses"("houseid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_similar_houses"("houseid" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_top_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_investments"("username" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_top_investors"("house_id" integer, "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_investors"("house_id" integer, "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_investors"("house_id" integer, "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_total_investments"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_total_investments"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_total_investments"("user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_total_investments"("house_id_val" integer, "user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_total_investments"("house_id_val" integer, "user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_total_investments"("house_id_val" integer, "user_name" "text", "start_date_val" "date", "end_date_val" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_total_profits"("h_id" integer, "username" "text", "start_date" "date", "end_date" "date", OUT "houseid" integer, OUT "my_profits" numeric, OUT "network_profits" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_total_profits"("h_id" integer, "username" "text", "start_date" "date", "end_date" "date", OUT "houseid" integer, OUT "my_profits" numeric, OUT "network_profits" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_total_profits"("h_id" integer, "username" "text", "start_date" "date", "end_date" "date", OUT "houseid" integer, OUT "my_profits" numeric, OUT "network_profits" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_transaction_label"("source" "text", "destination" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_transaction_label"("source" "text", "destination" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_transaction_label"("source" "text", "destination" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_transactions"("start_date" "date", "end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_transactions"("start_date" "date", "end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_transactions"("start_date" "date", "end_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_unread_notifications_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_notifications_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_notifications_count"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_week_profits"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_week_profits"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_week_profits"() TO "service_role";

GRANT ALL ON FUNCTION "public"."increase_user_balance"() TO "anon";
GRANT ALL ON FUNCTION "public"."increase_user_balance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increase_user_balance"() TO "service_role";

GRANT ALL ON FUNCTION "public"."increment_first_line"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_first_line"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_first_line"() TO "service_role";

GRANT ALL ON FUNCTION "public"."increment_second_line"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_second_line"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_second_line"() TO "service_role";

GRANT ALL ON FUNCTION "public"."increment_third_line"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_third_line"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_third_line"() TO "service_role";

GRANT ALL ON FUNCTION "public"."insert_referral_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."insert_referral_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_referral_func"() TO "service_role";

GRANT ALL ON FUNCTION "public"."is_booking_from_house"("booking_id" integer, "house_booking_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."is_booking_from_house"("booking_id" integer, "house_booking_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_booking_from_house"("booking_id" integer, "house_booking_id" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."limit_inviter"() TO "anon";
GRANT ALL ON FUNCTION "public"."limit_inviter"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limit_inviter"() TO "service_role";

GRANT ALL ON FUNCTION "public"."new_citizen_notification"("invited_by" "text", "username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."new_citizen_notification"("invited_by" "text", "username" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."new_citizen_notification"("invited_by" "text", "username" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."notiffications_promote_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."notiffications_promote_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notiffications_promote_trigger"() TO "service_role";

GRANT ALL ON FUNCTION "public"."notify_andreafuturi"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_andreafuturi"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_andreafuturi"() TO "service_role";

GRANT ALL ON FUNCTION "public"."notify_rank_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_rank_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_rank_change"() TO "service_role";

GRANT ALL ON FUNCTION "public"."notify_rank_change_network"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_rank_change_network"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_rank_change_network"() TO "service_role";

GRANT ALL ON FUNCTION "public"."notify_wallet_verification"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_wallet_verification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_wallet_verification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."reset_db"("delete_users" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."reset_db"("delete_users" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_db"("delete_users" boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."send_apartament_ownership_ended_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_apartament_ownership_ended_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_apartament_ownership_ended_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."send_booking_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_booking_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_booking_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."send_investment_almostcomplete_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_investment_almostcomplete_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_investment_almostcomplete_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."send_investment_completed_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_investment_completed_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_investment_completed_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."send_new_apartment_notification"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_new_apartment_notification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_new_apartment_notification"() TO "service_role";

GRANT ALL ON FUNCTION "public"."update_amount_reached"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_amount_reached"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_amount_reached"() TO "service_role";

GRANT ALL ON FUNCTION "public"."update_house_investors"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_house_investors"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_house_investors"() TO "service_role";

GRANT ALL ON FUNCTION "public"."update_profiles_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_profiles_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_profiles_email"() TO "service_role";

GRANT ALL ON FUNCTION "public"."update_total_investment"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_total_investment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_total_investment"() TO "service_role";

GRANT ALL ON FUNCTION "public"."update_user_password"("user_id" "uuid", "new_password" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_password"("user_id" "uuid", "new_password" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_password"("user_id" "uuid", "new_password" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."update_user_profits"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_profits"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_profits"() TO "service_role";

GRANT ALL ON FUNCTION "public"."validate_transaction_amount"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_transaction_amount"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_transaction_amount"() TO "service_role";

GRANT ALL ON FUNCTION "public"."verify_password"("entered_password" "text", "stored_hash" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."verify_password"("entered_password" "text", "stored_hash" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_password"("entered_password" "text", "stored_hash" "text") TO "service_role";

GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";

GRANT ALL ON SEQUENCE "public"."bookings_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."bookings_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."bookings_id_seq" TO "service_role";

GRANT ALL ON SEQUENCE "public"."houses_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."houses_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."houses_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."log" TO "anon";
GRANT ALL ON TABLE "public"."log" TO "authenticated";
GRANT ALL ON TABLE "public"."log" TO "service_role";

GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";
GRANT ALL ON TABLE "public"."notifications" TO PUBLIC;

GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";
GRANT SELECT,USAGE ON SEQUENCE "public"."notifications_id_seq" TO PUBLIC;

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";
GRANT ALL ON TABLE "public"."profiles" TO PUBLIC;
GRANT SELECT ON TABLE "public"."profiles" TO "supabase_auth_admin";

GRANT ALL ON TABLE "public"."profiles_view" TO "anon";
GRANT ALL ON TABLE "public"."profiles_view" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_view" TO "service_role";

GRANT ALL ON TABLE "public"."ranking" TO "anon";
GRANT ALL ON TABLE "public"."ranking" TO "authenticated";
GRANT ALL ON TABLE "public"."ranking" TO "service_role";

GRANT ALL ON TABLE "public"."referrals" TO "anon";
GRANT ALL ON TABLE "public"."referrals" TO "authenticated";
GRANT ALL ON TABLE "public"."referrals" TO "service_role";
GRANT ALL ON TABLE "public"."referrals" TO PUBLIC;

GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";

GRANT ALL ON SEQUENCE "public"."transactions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."transactions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."transactions_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."wallets" TO "anon";
GRANT ALL ON TABLE "public"."wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."wallets" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
