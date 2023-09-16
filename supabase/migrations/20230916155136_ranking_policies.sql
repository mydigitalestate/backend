CREATE POLICY "select_specific_ranking_policy" ON "public"."ranking"
AS PERMISSIVE FOR SELECT
TO authenticated
USING ((auth.uid() IS NOT NULL))
