CREATE POLICY "Enable insert for authenticated users only" ON "public"."houses"
AS PERMISSIVE FOR INSERT
TO authenticated

WITH CHECK (true);



CREATE POLICY "update_houses_policy" ON "public"."houses"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING ((auth.uid() IS NOT NULL))
