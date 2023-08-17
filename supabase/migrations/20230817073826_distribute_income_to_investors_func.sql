-- Create a trigger function
CREATE OR REPLACE FUNCTION distribute_income_to_investors_func()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;