-- ========================================================
-- UEM EATS - Fix Profiles RLS Recursion Migration
-- ========================================================
-- Bug Fix: PostgrestException 42P17 (infinite recursion in policy for relation "profiles")
-- Root Cause: Admin RLS policies were directly querying public.profiles inside the policy
--             using (SELECT role FROM profiles WHERE id = auth.uid()) = 'ADMIN'.
-- Solution: Create a SECURITY DEFINER function `public.is_admin()` that checks JWT metadata
--           and profiles via SECURITY DEFINER, bypassing RLS to avoid policy recursion.
-- ========================================================

-- 1. Create secure SECURITY DEFINER helper function to verify admin status without RLS recursion
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT (
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') = 'ADMIN'
    OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'ADMIN'
    )
  );
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;

-- 2. Drop the recursive profiles policy
DROP POLICY IF EXISTS "Admins full access to profiles" ON public.profiles;

-- 3. Ensure clean, non-recursive policies on profiles
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
ON public.profiles FOR SELECT TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 4. Re-create Admin policy on profiles using the non-recursive is_admin() function
CREATE POLICY "Admins full access to profiles"
ON public.profiles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 5. Update all other Admin policies across related tables to use public.is_admin()
DROP POLICY IF EXISTS "Admins full access to vendors" ON public.vendors;
CREATE POLICY "Admins full access to vendors"
ON public.vendors FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to menu items" ON public.menu_items;
CREATE POLICY "Admins full access to menu items"
ON public.menu_items FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to orders" ON public.orders;
CREATE POLICY "Admins full access to orders"
ON public.orders FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to order items" ON public.order_items;
CREATE POLICY "Admins full access to order items"
ON public.order_items FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins full access to payments" ON public.payments;
CREATE POLICY "Admins full access to payments"
ON public.payments FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 6. Update role escalation trigger function to use public.is_admin()
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
