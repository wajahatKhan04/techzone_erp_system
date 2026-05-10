-- ============================================================
-- TechZone ERP — Database Fix Script
-- Run this in pgAdmin to fix all 5 QA failures
-- ============================================================
-- Run after your main database is already set up
-- Safe to run multiple times (uses IF NOT EXISTS)
-- ============================================================

-- ── FIX 1: audit_log table ────────────────────────────────────
CREATE TABLE IF NOT EXISTS mini_erp.audit_log (
    log_id      SERIAL          PRIMARY KEY,
    table_name  VARCHAR(50)     NOT NULL,
    operation   VARCHAR(10)     NOT NULL,
    record_id   INT,
    changed_by  VARCHAR(100),
    old_values  JSONB,
    new_values  JSONB,
    changed_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_op CHECK (operation IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT'))
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON mini_erp.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_user  ON mini_erp.audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_audit_date  ON mini_erp.audit_log(changed_at DESC);

-- ── FIX 2: Purchase_Order table ───────────────────────────────
CREATE TABLE IF NOT EXISTS mini_erp.Purchase_Order (
    po_id       SERIAL          PRIMARY KEY,
    supplier_id INT             NOT NULL,
    product_id  INT             NOT NULL,
    quantity    INT             NOT NULL,
    unit_cost   DECIMAL(10,2)   NOT NULL,
    po_status   VARCHAR(20)     NOT NULL DEFAULT 'Pending',
    created_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_po_qty    CHECK (quantity > 0),
    CONSTRAINT chk_po_cost   CHECK (unit_cost > 0),
    CONSTRAINT chk_po_status CHECK (po_status IN ('Pending','Received','Cancelled')),
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id)
        REFERENCES mini_erp.Supplier(supplier_id) ON DELETE RESTRICT,
    CONSTRAINT fk_po_product FOREIGN KEY (product_id)
        REFERENCES mini_erp.Product(product_id) ON DELETE RESTRICT
);

-- Sample data for Purchase Orders
INSERT INTO mini_erp.Purchase_Order (supplier_id, product_id, quantity, unit_cost, po_status)
SELECT s.supplier_id, p.product_id, 20, ROUND((p.price * 0.72)::numeric, 2), 'Pending'
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.supplier_id = (SELECT MIN(supplier_id) FROM mini_erp.Supplier)
  AND p.product_id  = (SELECT MIN(product_id)  FROM mini_erp.Product)
  AND NOT EXISTS (SELECT 1 FROM mini_erp.Purchase_Order LIMIT 1);

-- ── FIX 3: payment_status column on Transaction ───────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mini_erp'
          AND table_name   = 'transaction'
          AND column_name  = 'payment_status'
    ) THEN
        ALTER TABLE mini_erp.Transaction
        ADD COLUMN payment_status VARCHAR(20) DEFAULT 'Paid'
            CHECK (payment_status IN ('Paid','Partial','Refunded','Pending'));

        UPDATE mini_erp.Transaction SET payment_status = 'Paid';
        RAISE NOTICE 'payment_status column added to Transaction table';
    ELSE
        RAISE NOTICE 'payment_status column already exists — skipping';
    END IF;
END$$;

-- ── FIX 4: Check Stock_Transaction column names ───────────────
-- Your existing table may use different column names
-- This checks and adds missing columns safely
DO $$
BEGIN
    -- Add transaction_type if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mini_erp'
          AND table_name   = 'stock_transaction'
          AND column_name  = 'transaction_type'
    ) THEN
        ALTER TABLE mini_erp.Stock_Transaction
        ADD COLUMN transaction_type VARCHAR(10) DEFAULT 'OUT'
            CHECK (transaction_type IN ('IN','OUT'));

        UPDATE mini_erp.Stock_Transaction SET transaction_type = 'OUT';
        RAISE NOTICE 'transaction_type column added to Stock_Transaction';
    ELSE
        RAISE NOTICE 'transaction_type already exists — skipping';
    END IF;

    -- Add transaction_date if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mini_erp'
          AND table_name   = 'stock_transaction'
          AND column_name  = 'transaction_date'
    ) THEN
        ALTER TABLE mini_erp.Stock_Transaction
        ADD COLUMN transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
        RAISE NOTICE 'transaction_date column added to Stock_Transaction';
    ELSE
        RAISE NOTICE 'transaction_date already exists — skipping';
    END IF;
END$$;

-- ── FIX 5: view_payment_status (6th view) ─────────────────────
CREATE OR REPLACE VIEW mini_erp.view_payment_status AS
SELECT
    o.order_id,
    c.name                                         AS customer_name,
    o.total_amount,
    COALESCE(SUM(t.amount), 0)                     AS paid_amount,
    o.total_amount - COALESCE(SUM(t.amount), 0)    AS balance_due,
    o.order_status,
    CASE
        WHEN o.total_amount - COALESCE(SUM(t.amount),0) <= 0 THEN 'Fully Paid'
        WHEN COALESCE(SUM(t.amount), 0) > 0                  THEN 'Partial'
        ELSE 'Unpaid'
    END AS payment_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c    ON o.customer_id = c.customer_id
LEFT JOIN mini_erp.Transaction t ON o.order_id = t.order_id
GROUP BY o.order_id, c.name, o.total_amount, o.order_status;

-- ── DCL: Grant permissions on new tables ──────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'erp_admin') THEN
        EXECUTE 'GRANT ALL PRIVILEGES ON mini_erp.audit_log TO erp_admin';
        EXECUTE 'GRANT ALL PRIVILEGES ON mini_erp.Purchase_Order TO erp_admin';
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE mini_erp.audit_log_log_id_seq TO erp_admin';
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE mini_erp.purchase_order_po_id_seq TO erp_admin';
    END IF;

    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'erp_inventory') THEN
        EXECUTE 'GRANT SELECT, INSERT ON mini_erp.Purchase_Order TO erp_inventory';
        EXECUTE 'GRANT UPDATE (po_status) ON mini_erp.Purchase_Order TO erp_inventory';
    END IF;
END$$;

-- ── VERIFICATION ──────────────────────────────────────────────
DO $$
DECLARE
    tbl_count INT;
    col_exists BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO tbl_count
    FROM information_schema.tables
    WHERE table_schema = 'mini_erp'
      AND table_name IN ('audit_log','purchase_order');

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mini_erp'
          AND table_name = 'transaction'
          AND column_name = 'payment_status'
    ) INTO col_exists;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'FIX RESULTS:';
    RAISE NOTICE 'New tables created: % of 2', tbl_count;
    RAISE NOTICE 'payment_status column exists: %', col_exists;
    RAISE NOTICE 'Run python test_techzone.py again to verify';
    RAISE NOTICE '========================================';
END$$;

-- ============================================================
-- END OF FIX SCRIPT
-- After running this, re-run: python test_techzone.py
-- Expected result: 60/60 PASS, QA Score 100%
-- ============================================================
