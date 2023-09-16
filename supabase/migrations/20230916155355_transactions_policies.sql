CREATE POLICY "insert_specific_transactions_policy" ON "public"."transactions"
AS PERMISSIVE FOR INSERT
TO authenticated

WITH CHECK ((auth.uid() IS NOT NULL));


CREATE POLICY "transactions_select_policy" ON "public"."transactions"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);


CREATE POLICY "update_specific_transactions_policy" ON "public"."transactions"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING ((auth.uid() IS NOT NULL))
