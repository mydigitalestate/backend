CREATE POLICY "select_specific_referrals_policy" ON "public"."referrals"
AS PERMISSIVE FOR SELECT
TO authenticated
USING ((auth.uid() IS NOT NULL))
