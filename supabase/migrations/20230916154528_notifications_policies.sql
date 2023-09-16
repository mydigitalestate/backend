CREATE POLICY "insert_notifications_policy" ON "public"."notifications"
AS PERMISSIVE FOR INSERT
TO authenticated

WITH CHECK ((auth.uid() IS NOT NULL));




CREATE POLICY "select_notifications_policy" ON "public"."notifications"
AS PERMISSIVE FOR SELECT
TO authenticated
USING ((((auth.uid() IS NOT NULL) AND (get_username(auth.uid()) = ANY (usernames))) OR (usernames IS NULL)));



CREATE POLICY "update_notifications_policy" ON "public"."notifications"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (((auth.uid() IS NOT NULL) AND check_notification_update_policy(get_username(auth.uid()), usernames)))


