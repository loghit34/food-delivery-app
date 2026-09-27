-- ========================================================
-- UEM EATS - Globally Unique Order ID Migration
-- ========================================================
-- Description:
-- Enforces globally unique, consecutive Order IDs across ALL canteens and vendors.
-- Replaces per-vendor/per-date numbering with an atomic global sequence and UNIQUE constraint.
-- Safe for existing databases: backfills existing orders in chronological order.
-- ========================================================

-- 1. Create a global sequence for order numbering across the entire application
CREATE SEQUENCE IF NOT EXISTS global_order_number_seq;

-- 2. Safely backfill existing orders in chronological order so all existing records are globally unique
WITH ordered_existing_orders AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC) AS new_seq
  FROM orders
)
UPDATE orders o
SET daily_order_number = oe.new_seq
FROM ordered_existing_orders oe
WHERE o.id = oe.id;

-- 3. Synchronize the global sequence counter with the highest existing order number
SELECT setval(
  'global_order_number_seq', 
  COALESCE((SELECT MAX(daily_order_number) FROM orders), 0)
);

-- 4. Add UNIQUE constraint to enforce global uniqueness across ALL canteens and vendors
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'orders_daily_order_number_unique' OR conname = 'orders_order_number_unique'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT orders_daily_order_number_unique UNIQUE (daily_order_number);
    END IF;
END $$;

-- 5. Create index for fast lookups on global order number
CREATE INDEX IF NOT EXISTS idx_orders_daily_order_number ON orders(daily_order_number);

-- 6. Trigger function: Atomically assign order_date and globally unique daily_order_number
CREATE OR REPLACE FUNCTION set_daily_order_details()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure status defaults to PENDING if not specified
    IF NEW.status IS NULL THEN
        NEW.status := 'PENDING';
    END IF;

    -- Calculate IST date (UTC+5:30) for order_date if not provided
    IF NEW.order_date IS NULL THEN
        NEW.order_date := ((COALESCE(NEW.created_at, NOW()) AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kolkata')::DATE;
    END IF;

    -- Atomically assign globally unique order number from sequence if not explicitly provided
    IF NEW.daily_order_number IS NULL OR NEW.daily_order_number <= 0 THEN
        NEW.daily_order_number := nextval('global_order_number_seq');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Ensure trigger is attached to orders table
DROP TRIGGER IF EXISTS tr_set_daily_order_details ON orders;
CREATE TRIGGER tr_set_daily_order_details
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION set_daily_order_details();
