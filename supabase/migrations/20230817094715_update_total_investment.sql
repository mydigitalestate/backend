CREATE OR REPLACE FUNCTION update_total_investment()
RETURNS TRIGGER AS $$

BEGIN
    IF (NEW.destination ~ '^[0-9]+$') THEN
        UPDATE profiles SET total_investments = total_investments + NEW.amount WHERE username = NEW.source;
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;