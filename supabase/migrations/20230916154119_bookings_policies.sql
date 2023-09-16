
CREATE POLICY "Enable insert for authenticated users only" ON "public"."bookings"
AS PERMISSIVE FOR INSERT
TO authenticated

WITH CHECK (true)