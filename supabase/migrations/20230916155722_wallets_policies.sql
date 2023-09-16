CREATE POLICY "Enable delete for users based on owned_by" ON "public"."wallets"
AS PERMISSIVE FOR DELETE
TO authenticated
USING ((get_username(auth.uid()) = owned_by));



CREATE POLICY "Enable update for wallets owned by logged in user" ON "public"."wallets"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING ((get_username(auth.uid()) = owned_by))
WITH CHECK ((get_username(auth.uid()) = owned_by));



CREATE POLICY "insert_specific_wallets_policy" ON "public"."wallets"
AS PERMISSIVE FOR INSERT
TO authenticated

WITH CHECK ((auth.uid() IS NOT NULL));



CREATE POLICY "select_specific_wallets_policy" ON "public"."wallets"
AS PERMISSIVE FOR SELECT
TO authenticated
USING (((auth.uid() IS NOT NULL) AND (get_username(auth.uid()) = ANY (ARRAY[owned_by]))))
