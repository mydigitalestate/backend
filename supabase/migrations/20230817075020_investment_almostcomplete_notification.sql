CREATE OR REPLACE FUNCTION send_investment_almostcomplete_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Notifications (usernames, title, message, image, link, icon, color)
    VALUES (NEW.investors, 'Investment Almost Completed', 'Only ' || (NEW.total_required - NEW.amount_reached) || ' USDT to unlock ' || NEW.name || '’s profits!', NEW.images[1], 'investment/' || NEW.id, 'almost', 'info');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;