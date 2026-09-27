-- ========================================================
-- UEM EATS - Production Security & Hardening Migration
-- ========================================================
-- 1. Updates order status check constraint to support CANCELLED and REFUNDED.
-- 2. Non-recursive SECURITY DEFINER admin helper function.
-- 3. Hardens profiles role trigger against privilege escalation on INSERT.
-- 4. Adds Admin Row Level Security (RLS) policies without recursion.
-- ========================================================

-- 1. Update Order Status Constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
    CHECK (status IN ('PENDING', 'COMPLETED', 'PAID', 'CANCELLED', 'REFUNDED'));

-- 2. Non-recursive SECURITY DEFINER helper function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'ADMIN'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;

-- 3. Harden Profile Role Escalation Trigger (enforce on INSERT and UPDATE)
CREATE OR REPLACE FUNCTION prevent_profile_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow service_role (backend admin operations) to assign any role
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Allow ADMIN users to change roles
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- On INSERT: Restrict self-registration strictly to STUDENT or FACULTY
  IF TG_OP = 'INSERT' THEN
    IF NEW.role NOT IN ('STUDENT', 'FACULTY') THEN
      RAISE EXCEPTION 'Privilege escalation blocked: Self-registration is restricted to STUDENT and FACULTY.';
    END IF;
  END IF;

  -- On UPDATE: Disallow any client role modification for non-admins
  IF TG_OP = 'UPDATE' THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Privilege escalation blocked: Users cannot change their own system role.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_prevent_profile_role_escalation ON profiles;
CREATE TRIGGER tr_prevent_profile_role_escalation
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW
EXECUTE PROCEDURE prevent_profile_role_escalation();

-- 4. Clean and re-create Admin Universal RLS Policies using public.is_admin()
DROP POLICY IF EXISTS "Admins full access to profiles" ON profiles;
CREATE POLICY "Admins full access to profiles" ON profiles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to vendors" ON vendors;
CREATE POLICY "Admins full access to vendors" ON vendors FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to menu items" ON menu_items;
CREATE POLICY "Admins full access to menu items" ON menu_items FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to orders" ON orders;
CREATE POLICY "Admins full access to orders" ON orders FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to order items" ON order_items;
CREATE POLICY "Admins full access to order items" ON order_items FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to payments" ON payments;
CREATE POLICY "Admins full access to payments" ON payments FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
