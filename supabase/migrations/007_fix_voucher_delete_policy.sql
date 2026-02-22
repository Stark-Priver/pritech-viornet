-- Fix voucher delete policy to allow SUPER_ADMIN as well as ADMIN
DROP POLICY IF EXISTS "Admin can delete vouchers" ON vouchers;

CREATE POLICY "Admin and SuperAdmin can delete vouchers"
ON vouchers FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = (
      SELECT id FROM users WHERE users.id = auth.uid()::int LIMIT 1
    )
    AND users.role IN ('ADMIN', 'SUPER_ADMIN')
    AND users.is_active = true
  )
);
