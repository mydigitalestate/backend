CREATE POLICY "Enable insert for registration" ON "public"."profiles"
AS PERMISSIVE FOR INSERT
TO public

WITH CHECK (true);




CREATE POLICY "Enable own update access for authenticated users" ON "public"."profiles"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING ((id = auth.uid()))
WITH CHECK ((id = auth.uid()));


CREATE POLICY "select_own_profile" ON "public"."profiles"
AS PERMISSIVE FOR SELECT
TO authenticated
USING ((auth.uid() = id))
