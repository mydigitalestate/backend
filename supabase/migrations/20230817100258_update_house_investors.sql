CREATE OR REPLACE FUNCTION update_house_investors()
RETURNS TRIGGER AS $$
BEGIN
-- Check if the destination ID is a valid integer
    IF (NEW.destination ~ '^[0-9]+$') THEN
        -- Check if the source value is already in the investors array
        IF NOT (NEW.source = ANY(SELECT unnest(investors) FROM houses WHERE id = NEW.destination::integer)) THEN
            -- Append the source value to the investors array
            UPDATE houses SET investors = array_append(investors, NEW.source) WHERE id = NEW.destination::integer;
        END IF;
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;