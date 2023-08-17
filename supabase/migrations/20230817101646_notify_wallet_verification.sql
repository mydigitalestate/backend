CREATE OR REPLACE FUNCTION notify_wallet_verification()
RETURNS TRIGGER AS $$

BEGIN
    IF NEW.is_verified = TRUE AND OLD.is_verified = FALSE THEN
        INSERT INTO Notifications (usernames, title, message, link,icon,image)
        VALUES (ARRAY[NEW.owned_by], 'New Wallet Linked', 'Your wallet has been verified!', 'settings' ,'verified','verified');
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;