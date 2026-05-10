-- ============================================================
-- TechZone Pvt Ltd — Mini ERP Database
-- Complete SQL File (Schema + Data + Views + Triggers + DCL)
-- ============================================================
-- Course  : CS2013 — Introduction to Database Systems
-- Program : BS FinTech — FAST NUCES Karachi
-- Members : Muhammad Wajahat Khan (24K-5554)
--           Muhammad Haider Hasnain (24K-5589)
-- Version : 2.0 (with AI Reorder + Profit Margins + Audit Log)
-- ============================================================
-- HOW TO RUN:
-- 1. Open pgAdmin
-- 2. Create database named: mini_erp_db
-- 3. Open Query Tool
-- 4. Paste this entire file and click Run (F5)
-- ============================================================

-- ── CREATE SCHEMA ─────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS mini_erp;
SET search_path TO mini_erp;

-- ============================================================
-- SECTION 1: DDL — TABLE CREATION
-- ============================================================

-- 1. Category Table
CREATE TABLE IF NOT EXISTS mini_erp.Category (
    category_id     SERIAL          PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL UNIQUE
);

-- 2. Product Table
CREATE TABLE IF NOT EXISTS mini_erp.Product (
    product_id      SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    price           DECIMAL(10,2)   NOT NULL,
    stock_quantity  INT             NOT NULL DEFAULT 0,
    category_id     INT             NOT NULL,
    CONSTRAINT chk_product_price   CHECK (price > 0),
    CONSTRAINT chk_stock_qty       CHECK (stock_quantity >= 0),
    CONSTRAINT fk_product_cat      FOREIGN KEY (category_id)
                                   REFERENCES mini_erp.Category(category_id)
                                   ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 3. Customer Table
CREATE TABLE IF NOT EXISTS mini_erp.Customer (
    customer_id     SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    phone           VARCHAR(20)     UNIQUE,
    email           VARCHAR(100)    UNIQUE,
    address         TEXT,
    customer_status VARCHAR(20)     NOT NULL DEFAULT 'Active',
    join_date       TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_customer_status CHECK (customer_status IN ('Active','Inactive','Blocked'))
);

-- 4. Supplier Table
CREATE TABLE IF NOT EXISTS mini_erp.Supplier (
    supplier_id     SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    contact         VARCHAR(20),
    city            VARCHAR(50),
    supplier_status VARCHAR(20)     NOT NULL DEFAULT 'Active',
    join_date       TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supplier_status CHECK (supplier_status IN ('Active','Inactive'))
);

-- 5. Employee Table
CREATE TABLE IF NOT EXISTS mini_erp.Employee (
    employee_id     SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    role            VARCHAR(50),
    phone           VARCHAR(20),
    email           VARCHAR(100)    UNIQUE,
    hire_date       TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

-- 6. Orders Table
CREATE TABLE IF NOT EXISTS mini_erp.Orders (
    order_id        SERIAL          PRIMARY KEY,
    customer_id     INT             NOT NULL,
    employee_id     INT,
    order_date      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    total_amount    DECIMAL(10,2)   DEFAULT 0,
    order_status    VARCHAR(20)     NOT NULL DEFAULT 'Pending',
    CONSTRAINT chk_order_status    CHECK (order_status IN ('Pending','Completed','Cancelled')),
    CONSTRAINT fk_order_customer   FOREIGN KEY (customer_id)
                                   REFERENCES mini_erp.Customer(customer_id)
                                   ON DELETE RESTRICT,
    CONSTRAINT fk_order_employee   FOREIGN KEY (employee_id)
                                   REFERENCES mini_erp.Employee(employee_id)
                                   ON DELETE SET NULL
);

-- 7. Order_Details (Junction Table: Orders ↔ Product)
CREATE TABLE IF NOT EXISTS mini_erp.Order_Details (
    order_id        INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL,
    price           DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT chk_od_qty          CHECK (quantity > 0),
    CONSTRAINT chk_od_price        CHECK (price > 0),
    CONSTRAINT fk_od_order         FOREIGN KEY (order_id)
                                   REFERENCES mini_erp.Orders(order_id)
                                   ON DELETE CASCADE,
    CONSTRAINT fk_od_product       FOREIGN KEY (product_id)
                                   REFERENCES mini_erp.Product(product_id)
                                   ON DELETE RESTRICT
);

-- 8. Supplier_Product (Junction Table: Supplier ↔ Product)
CREATE TABLE IF NOT EXISTS mini_erp.Supplier_Product (
    supplier_id     INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL DEFAULT 0,
    supply_price    DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (supplier_id, product_id),
    CONSTRAINT chk_sp_qty          CHECK (quantity >= 0),
    CONSTRAINT chk_sp_price        CHECK (supply_price > 0),
    CONSTRAINT fk_sp_supplier      FOREIGN KEY (supplier_id)
                                   REFERENCES mini_erp.Supplier(supplier_id)
                                   ON DELETE RESTRICT,
    CONSTRAINT fk_sp_product       FOREIGN KEY (product_id)
                                   REFERENCES mini_erp.Product(product_id)
                                   ON DELETE RESTRICT
);

-- 9. Transaction Table
CREATE TABLE IF NOT EXISTS mini_erp.Transaction (
    transaction_id  SERIAL          PRIMARY KEY,
    order_id        INT             NOT NULL UNIQUE,
    amount          DECIMAL(10,2)   NOT NULL,
    payment_method  VARCHAR(20)     NOT NULL,
    payment_status  VARCHAR(20)     DEFAULT 'Paid',
    transaction_date TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_method  CHECK (payment_method IN ('Bank Transfer','Card','Cash')),
    CONSTRAINT chk_payment_status  CHECK (payment_status IN ('Paid','Partial','Refunded','Pending')),
    CONSTRAINT fk_txn_order        FOREIGN KEY (order_id)
                                   REFERENCES mini_erp.Orders(order_id)
                                   ON DELETE CASCADE
);

-- 10. Stock_Transaction Table
CREATE TABLE IF NOT EXISTS mini_erp.Stock_Transaction (
    stock_txn_id        SERIAL      PRIMARY KEY,
    product_id          INT         NOT NULL,
    transaction_type    VARCHAR(10) NOT NULL,
    quantity            INT         NOT NULL,
    transaction_date    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_stxn_type       CHECK (transaction_type IN ('IN','OUT')),
    CONSTRAINT chk_stxn_qty        CHECK (quantity > 0),
    CONSTRAINT fk_stxn_product     FOREIGN KEY (product_id)
                                   REFERENCES mini_erp.Product(product_id)
                                   ON DELETE RESTRICT
);

-- 11. Users Table (for login)
CREATE TABLE IF NOT EXISTS mini_erp.Users (
    user_id     SERIAL          PRIMARY KEY,
    username    VARCHAR(50)     NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    role        VARCHAR(20)     NOT NULL,
    full_name   VARCHAR(100)    NOT NULL,
    CONSTRAINT chk_user_role    CHECK (role IN ('admin','sales','inventory'))
);

-- 12. Purchase_Order Table (NEW — Innovation)
CREATE TABLE IF NOT EXISTS mini_erp.Purchase_Order (
    po_id           SERIAL          PRIMARY KEY,
    supplier_id     INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL,
    unit_cost       DECIMAL(10,2)   NOT NULL,
    po_status       VARCHAR(20)     NOT NULL DEFAULT 'Pending',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_po_qty          CHECK (quantity > 0),
    CONSTRAINT chk_po_cost         CHECK (unit_cost > 0),
    CONSTRAINT chk_po_status       CHECK (po_status IN ('Pending','Received','Cancelled')),
    CONSTRAINT fk_po_supplier      FOREIGN KEY (supplier_id)
                                   REFERENCES mini_erp.Supplier(supplier_id)
                                   ON DELETE RESTRICT,
    CONSTRAINT fk_po_product       FOREIGN KEY (product_id)
                                   REFERENCES mini_erp.Product(product_id)
                                   ON DELETE RESTRICT
);

-- 13. Audit Log Table (NEW — Innovation)
CREATE TABLE IF NOT EXISTS mini_erp.audit_log (
    log_id      SERIAL          PRIMARY KEY,
    table_name  VARCHAR(50)     NOT NULL,
    operation   VARCHAR(10)     NOT NULL,
    record_id   INT,
    changed_by  VARCHAR(100),
    old_values  JSONB,
    new_values  JSONB,
    changed_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_op     CHECK (operation IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT'))
);

-- Indexes for audit log
CREATE INDEX IF NOT EXISTS idx_audit_table ON mini_erp.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_user  ON mini_erp.audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_audit_date  ON mini_erp.audit_log(changed_at DESC);

-- ============================================================
-- SECTION 2: DML — SAMPLE DATA
-- ============================================================

-- Categories (8)
INSERT INTO mini_erp.Category (category_name) VALUES
('Laptops & Notebooks'),
('Desktop Computers'),
('Networking Equipment'),
('Servers & Storage'),
('Printers & Scanners'),
('UPS & Power'),
('Monitors & Displays'),
('Accessories & Cables')
ON CONFLICT DO NOTHING;

-- Products (15)
INSERT INTO mini_erp.Product (name, price, stock_quantity, category_id) VALUES
('Dell Latitude 5540 Core i7',       185000, 25, 1),
('HP ProBook 450 G10',               165000, 18, 1),
('Lenovo ThinkPad E15',              175000, 12, 1),
('Dell OptiPlex 7010 Desktop',       120000, 30, 2),
('HP EliteDesk 800 G9',             115000,  8, 2),
('Cisco Catalyst 2960 Switch',        95000, 15, 3),
('TP-Link TL-SG1024 Switch',         18000, 40, 3),
('Dell PowerEdge R350 Server',       850000,  5, 4),
('HP LaserJet Pro M404dn',           75000, 20, 5),
('Epson EcoTank L3250',              45000, 22, 5),
('APC Smart-UPS 1500VA',             65000,  6, 6),
('Cisco 1000W UPS',                  85000,  4, 6),
('Dell 24" Monitor P2422H',          55000, 35, 7),
('HP 27" IPS Monitor',               72000, 28, 7),
('Cat6 Ethernet Cable (50m)',         3500, 100, 8)
ON CONFLICT DO NOTHING;

-- Customers (12 corporate clients)
INSERT INTO mini_erp.Customer (name, phone, email, address, customer_status) VALUES
('Meezan Bank Head Office',     '021-111-331-331', 'it@meezanbank.com',      'SITE, Karachi',            'Active'),
('National Bank of Pakistan',   '021-111-627-627', 'procurement@nbp.com.pk', 'I.I. Chundrigar Rd, KHI',  'Active'),
('FAST NUCES Karachi',          '021-34390206',    'ict@nu.edu.pk',           'Block B SITE, Karachi',    'Active'),
('Aga Khan Hospital',           '021-34930051',    'it@aku.edu',              'Stadium Road, Karachi',    'Active'),
('K-Electric Ltd',              '021-99333333',    'vendor@ke.com.pk',        'Korangi, Karachi',         'Active'),
('PTCL Karachi Region',         '021-111-787-787', 'procurement@ptcl.net.pk', 'Karachi',                  'Active'),
('HBL Corporate',               '021-111-425-425', 'it.vendor@hbl.com',       'Habib Square, Karachi',   'Active'),
('University of Karachi',       '021-99261300',    'ict@uok.edu.pk',          'University Road, KHI',    'Active'),
('Pakistan Steel Mills',        '021-34721001',    'it@paksteel.com.pk',      'Bin Qasim, Karachi',      'Inactive'),
('Karachi Port Trust',          '021-32202901',    'it@kpt.gov.pk',           'KPT Building, Karachi',   'Active'),
('Dow University Hospital',     '021-38771111',    'procurement@duhs.edu.pk', 'Ojha Campus, Karachi',    'Active'),
('Sindh Government IT Dept',    '021-99211234',    'it@sindh.gov.pk',         'Secretariat, Karachi',    'Blocked')
ON CONFLICT DO NOTHING;

-- Suppliers (10)
INSERT INTO mini_erp.Supplier (name, contact, city, supplier_status) VALUES
('Dell Technologies Pakistan',  '021-35640001', 'Karachi',   'Active'),
('HP Pakistan Pvt Ltd',         '021-35640002', 'Karachi',   'Active'),
('Cisco Systems Pakistan',      '051-2890001',  'Islamabad', 'Active'),
('Lenovo Pakistan',             '042-35760001', 'Lahore',    'Active'),
('TP-Link Pakistan',            '021-34500001', 'Karachi',   'Active'),
('APC by Schneider Electric',   '021-35640005', 'Karachi',   'Active'),
('Epson Pakistan',              '021-34500002', 'Karachi',   'Active'),
('Ingram Micro Pakistan',       '021-35640010', 'Karachi',   'Active'),
('Tech Access Pakistan',        '042-35760005', 'Lahore',    'Inactive'),
('Vision Technologies',         '021-34500010', 'Karachi',   'Active')
ON CONFLICT DO NOTHING;

-- Employees (8)
INSERT INTO mini_erp.Employee (name, role, phone, email) VALUES
('Zafar Iqbal',     'Sales Manager',       '0300-1234567', 'zafar@techzone.pk'),
('Sana Mirza',      'Sales Executive',     '0301-2345678', 'sana@techzone.pk'),
('Hira Fatima',     'Inventory Manager',   '0302-3456789', 'hira@techzone.pk'),
('Ahmed Raza',      'Sales Executive',     '0303-4567890', 'ahmed@techzone.pk'),
('Bilal Hassan',    'Warehouse Staff',     '0304-5678901', 'bilal@techzone.pk'),
('Nadia Khan',      'Accountant',          '0305-6789012', 'nadia@techzone.pk'),
('Usman Ali',       'IT Support',          '0306-7890123', 'usman@techzone.pk'),
('Fatima Sheikh',   'Operations Manager',  '0307-8901234', 'fatima@techzone.pk')
ON CONFLICT DO NOTHING;

-- Users (3 role-based accounts)
INSERT INTO mini_erp.Users (username, password, role, full_name) VALUES
('admin',     'admin123', 'admin',     'Zafar Iqbal — Admin'),
('sales',     'sales123', 'sales',     'Sana Mirza — Sales'),
('inventory', 'inv123',   'inventory', 'Hira Fatima — Inventory')
ON CONFLICT DO NOTHING;

-- Supplier_Product (supply relationships with costs)
INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 50, ROUND((p.price * 0.72)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'Dell Technologies Pakistan'
  AND p.name IN ('Dell Latitude 5540 Core i7','Dell OptiPlex 7010 Desktop','Dell PowerEdge R350 Server','Dell 24" Monitor P2422H')
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 40, ROUND((p.price * 0.73)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'HP Pakistan Pvt Ltd'
  AND p.name IN ('HP ProBook 450 G10','HP EliteDesk 800 G9','HP LaserJet Pro M404dn','HP 27" IPS Monitor')
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 30, ROUND((p.price * 0.70)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'Cisco Systems Pakistan'
  AND p.name IN ('Cisco Catalyst 2960 Switch','Cisco 1000W UPS')
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 35, ROUND((p.price * 0.74)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'Lenovo Pakistan'
  AND p.name = 'Lenovo ThinkPad E15'
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 100, ROUND((p.price * 0.68)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'TP-Link Pakistan'
  AND p.name IN ('TP-Link TL-SG1024 Switch','Cat6 Ethernet Cable (50m)')
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 25, ROUND((p.price * 0.71)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'APC by Schneider Electric'
  AND p.name = 'APC Smart-UPS 1500VA'
ON CONFLICT DO NOTHING;

INSERT INTO mini_erp.Supplier_Product (supplier_id, product_id, quantity, supply_price)
SELECT s.supplier_id, p.product_id, 30, ROUND((p.price * 0.72)::numeric, 2)
FROM mini_erp.Supplier s, mini_erp.Product p
WHERE s.name = 'Epson Pakistan'
  AND p.name = 'Epson EcoTank L3250'
ON CONFLICT DO NOTHING;

-- Orders (15 sample orders)
INSERT INTO mini_erp.Orders (customer_id, employee_id, order_date, total_amount, order_status) VALUES
(1, 1, '2026-01-15 10:30:00', 925000,  'Completed'),
(2, 2, '2026-01-22 11:00:00', 480000,  'Completed'),
(3, 1, '2026-02-05 09:15:00', 370000,  'Completed'),
(4, 2, '2026-02-14 14:00:00', 750000,  'Completed'),
(5, 3, '2026-02-20 10:00:00', 285000,  'Completed'),
(6, 1, '2026-03-01 09:00:00', 190000,  'Completed'),
(7, 2, '2026-03-10 11:30:00', 520000,  'Completed'),
(1, 1, '2026-03-18 10:00:00', 340000,  'Completed'),
(8, 3, '2026-04-02 09:30:00', 465000,  'Completed'),
(2, 2, '2026-04-10 14:00:00', 185000,  'Completed'),
(4, 1, '2026-04-15 11:00:00', 850000,  'Completed'),
(3, 2, '2026-04-20 10:30:00', 130000,  'Pending'),
(10, 1, '2026-04-22 09:00:00', 275000, 'Pending'),
(11, 3, '2026-04-25 14:30:00', 220000, 'Pending'),
(7,  2, '2026-04-28 10:00:00', 95000,  'Cancelled')
ON CONFLICT DO NOTHING;

-- Order Details
INSERT INTO mini_erp.Order_Details (order_id, product_id, quantity, price) VALUES
(1, 1, 5, 185000), -- Dell Latitude x5
(2, 3, 2, 175000), (2, 6, 1, 95000), -- Lenovo + Cisco
(3, 2, 2, 165000), (3, 13, 1, 55000), -- HP ProBook + Monitor
(4, 8, 1, 850000), -- Server
(5, 9, 3, 75000),  (5, 10, 1, 45000), -- Printers
(6, 13, 2, 55000), (6, 15, 20, 3500), -- Monitors + Cables
(7, 1, 2, 185000), (7, 4, 1, 120000), -- Dell Laptop + Desktop
(8, 2, 2, 165000),                    -- HP ProBook
(9, 5, 1, 115000), (9, 7, 5, 18000), (9, 15, 50, 3500), -- Desktop + Switch + Cables
(10, 1, 1, 185000),                   -- Dell Latitude
(11, 8, 1, 850000),                   -- Server
(12, 14, 1, 72000), (12, 13, 1, 55000), -- Monitors
(13, 6, 1, 95000), (13, 7, 5, 18000), -- Switches
(14, 11, 2, 65000), (14, 12, 1, 85000) -- UPS
ON CONFLICT DO NOTHING;

-- Transactions
INSERT INTO mini_erp.Transaction (order_id, amount, payment_method, payment_status) VALUES
(1,  925000, 'Bank Transfer', 'Paid'),
(2,  480000, 'Bank Transfer', 'Paid'),
(3,  370000, 'Card',          'Paid'),
(4,  750000, 'Bank Transfer', 'Paid'),
(5,  285000, 'Cash',          'Paid'),
(6,  190000, 'Card',          'Paid'),
(7,  520000, 'Bank Transfer', 'Paid'),
(8,  340000, 'Bank Transfer', 'Paid'),
(9,  465000, 'Card',          'Paid'),
(10, 185000, 'Cash',          'Paid'),
(11, 850000, 'Bank Transfer', 'Paid')
ON CONFLICT DO NOTHING;

-- Stock Transactions
INSERT INTO mini_erp.Stock_Transaction (product_id, transaction_type, quantity) VALUES
(1, 'OUT', 5), (3, 'OUT', 2), (6, 'OUT', 1), (2, 'OUT', 2),
(13,'OUT', 1), (8, 'OUT', 1), (9, 'OUT', 3), (10,'OUT', 1),
(13,'OUT', 2), (15,'OUT',20), (1, 'OUT', 2), (4, 'OUT', 1),
(2, 'OUT', 2), (5, 'OUT', 1), (7, 'OUT', 5), (15,'OUT',50),
(1, 'OUT', 1), (8, 'OUT', 1)
ON CONFLICT DO NOTHING;

-- Sample Purchase Orders (NEW)
INSERT INTO mini_erp.Purchase_Order (supplier_id, product_id, quantity, unit_cost, po_status) VALUES
(1, 5,  20, 82800,  'Pending'),
(3, 12, 10, 59500,  'Pending'),
(6, 11, 15, 46150,  'Received'),
(2, 2,  25, 120450, 'Received'),
(5, 7,  50, 12240,  'Cancelled')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SECTION 3: VIEWS (6 Reporting Views)
-- ============================================================

-- View 1: Sales Report
CREATE OR REPLACE VIEW mini_erp.view_sales_report AS
SELECT
    o.order_id,
    c.name                                          AS customer_name,
    e.name                                          AS employee_name,
    TO_CHAR(o.order_date, 'DD Mon YYYY')            AS order_date,
    o.total_amount,
    o.order_status,
    t.payment_method,
    t.amount                                        AS paid_amount,
    t.payment_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c    ON o.customer_id  = c.customer_id
LEFT JOIN mini_erp.Employee e    ON o.employee_id  = e.employee_id
LEFT JOIN mini_erp.Transaction t ON o.order_id     = t.order_id
ORDER BY o.order_date DESC;

-- View 2: Inventory Status
CREATE OR REPLACE VIEW mini_erp.view_inventory_status AS
SELECT
    p.product_id,
    p.name                                          AS product_name,
    c.category_name,
    p.price,
    p.stock_quantity,
    CASE
        WHEN p.stock_quantity = 0    THEN 'Out of Stock'
        WHEN p.stock_quantity < 10   THEN 'Critical'
        WHEN p.stock_quantity < 20   THEN 'Low Stock'
        ELSE 'In Stock'
    END                                             AS stock_status
FROM mini_erp.Product p
JOIN mini_erp.Category c ON p.category_id = c.category_id
ORDER BY p.stock_quantity ASC;

-- View 3: Customer Purchase History
CREATE OR REPLACE VIEW mini_erp.view_customer_purchase_history AS
SELECT
    c.customer_id,
    c.name                                          AS customer_name,
    c.customer_status,
    COUNT(o.order_id)                               AS total_orders,
    COALESCE(SUM(o.total_amount), 0)                AS total_spent,
    COALESCE(MAX(o.order_date), NULL)               AS last_order_date,
    COUNT(CASE WHEN o.order_status='Completed' THEN 1 END) AS completed_orders,
    COUNT(CASE WHEN o.order_status='Pending'   THEN 1 END) AS pending_orders
FROM mini_erp.Customer c
LEFT JOIN mini_erp.Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name, c.customer_status
ORDER BY total_spent DESC;

-- View 4: Supplier Supply Records
CREATE OR REPLACE VIEW mini_erp.view_supplier_supply_records AS
SELECT
    s.supplier_id,
    s.name                                          AS supplier_name,
    s.city,
    s.supplier_status,
    COUNT(sp.product_id)                            AS products_supplied,
    COALESCE(SUM(sp.quantity), 0)                   AS total_units_supplied,
    COALESCE(SUM(sp.quantity * sp.supply_price), 0) AS total_supply_value
FROM mini_erp.Supplier s
LEFT JOIN mini_erp.Supplier_Product sp ON s.supplier_id = sp.supplier_id
GROUP BY s.supplier_id, s.name, s.city, s.supplier_status
ORDER BY total_supply_value DESC;

-- View 5: Transaction Summary
CREATE OR REPLACE VIEW mini_erp.view_transaction_summary AS
SELECT
    t.transaction_id,
    c.name                                          AS customer_name,
    o.order_id,
    t.amount,
    t.payment_method,
    t.payment_status,
    TO_CHAR(t.transaction_date, 'DD Mon YYYY')      AS transaction_date,
    o.order_status
FROM mini_erp.Transaction t
JOIN mini_erp.Orders o  ON t.order_id    = o.order_id
JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
ORDER BY t.transaction_date DESC;

-- View 6: Payment Balance (NEW — Innovation)
CREATE OR REPLACE VIEW mini_erp.view_payment_status AS
SELECT
    o.order_id,
    c.name                                          AS customer_name,
    o.total_amount,
    COALESCE(SUM(t.amount), 0)                      AS paid_amount,
    o.total_amount - COALESCE(SUM(t.amount), 0)     AS balance_due,
    o.order_status,
    CASE
        WHEN o.total_amount - COALESCE(SUM(t.amount),0) <= 0 THEN 'Fully Paid'
        WHEN COALESCE(SUM(t.amount), 0) > 0               THEN 'Partial'
        ELSE 'Unpaid'
    END                                             AS payment_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c   ON o.customer_id = c.customer_id
LEFT JOIN mini_erp.Transaction t ON o.order_id = t.order_id
GROUP BY o.order_id, c.name, o.total_amount, o.order_status;

-- ============================================================
-- SECTION 4: TRIGGERS (5 Automation Triggers)
-- ============================================================

-- Trigger 1: Check stock before order
CREATE OR REPLACE FUNCTION mini_erp.fn_check_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT stock_quantity FROM mini_erp.Product WHERE product_id = NEW.product_id) < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product_id %. Available: %, Requested: %',
            NEW.product_id,
            (SELECT stock_quantity FROM mini_erp.Product WHERE product_id = NEW.product_id),
            NEW.quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_stock ON mini_erp.Order_Details;
CREATE TRIGGER trg_check_stock
    BEFORE INSERT ON mini_erp.Order_Details
    FOR EACH ROW EXECUTE FUNCTION mini_erp.fn_check_stock();

-- Trigger 2: Decrease stock after order
CREATE OR REPLACE FUNCTION mini_erp.fn_decrease_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_decrease_stock ON mini_erp.Order_Details;
CREATE TRIGGER trg_decrease_stock
    AFTER INSERT ON mini_erp.Order_Details
    FOR EACH ROW EXECUTE FUNCTION mini_erp.fn_decrease_stock();

-- Trigger 3: Update order total automatically
CREATE OR REPLACE FUNCTION mini_erp.fn_update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mini_erp.Orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * price), 0)
        FROM mini_erp.Order_Details
        WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_order_total ON mini_erp.Order_Details;
CREATE TRIGGER trg_update_order_total
    AFTER INSERT ON mini_erp.Order_Details
    FOR EACH ROW EXECUTE FUNCTION mini_erp.fn_update_order_total();

-- Trigger 4: Increase stock when supplier product added
CREATE OR REPLACE FUNCTION mini_erp.fn_increase_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_increase_stock ON mini_erp.Supplier_Product;
CREATE TRIGGER trg_increase_stock
    AFTER INSERT ON mini_erp.Supplier_Product
    FOR EACH ROW EXECUTE FUNCTION mini_erp.fn_increase_stock();

-- Trigger 5: Log order status changes
CREATE OR REPLACE FUNCTION mini_erp.fn_log_order_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.order_status <> NEW.order_status THEN
        RAISE NOTICE 'Order #% status changed: % → %', NEW.order_id, OLD.order_status, NEW.order_status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_order_status ON mini_erp.Orders;
CREATE TRIGGER trg_log_order_status
    AFTER UPDATE ON mini_erp.Orders
    FOR EACH ROW EXECUTE FUNCTION mini_erp.fn_log_order_status();

-- ============================================================
-- SECTION 5: TCL — Transaction Examples
-- ============================================================

-- Example: Complete order placement as atomic transaction
-- BEGIN;
--   INSERT INTO mini_erp.Orders(customer_id, employee_id) VALUES(1, 1);
--   INSERT INTO mini_erp.Order_Details(order_id, product_id, quantity, price)
--     VALUES(currval('mini_erp.orders_order_id_seq'), 1, 2, 185000);
--   INSERT INTO mini_erp.Transaction(order_id, amount, payment_method)
--     VALUES(currval('mini_erp.orders_order_id_seq'), 370000, 'Bank Transfer');
-- COMMIT;

-- Example: Rollback on error
-- BEGIN;
--   INSERT INTO mini_erp.Orders(customer_id, employee_id) VALUES(1, 1);
--   -- Something goes wrong
-- ROLLBACK;

-- ============================================================
-- SECTION 6: DCL — Role-Based Access Control
-- ============================================================

-- Create roles (run as superuser)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'erp_admin') THEN
        CREATE ROLE erp_admin LOGIN PASSWORD 'Admin@TechZone2026';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'erp_sales') THEN
        CREATE ROLE erp_sales LOGIN PASSWORD 'Sales@TechZone2026';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'erp_inventory') THEN
        CREATE ROLE erp_inventory LOGIN PASSWORD 'Inv@TechZone2026';
    END IF;
END$$;

-- Grant schema usage
GRANT USAGE ON SCHEMA mini_erp TO erp_admin, erp_sales, erp_inventory;

-- Admin: full access
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA mini_erp TO erp_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA mini_erp TO erp_admin;

-- Sales: orders, customers, transactions
GRANT SELECT, INSERT ON mini_erp.Orders, mini_erp.Order_Details TO erp_sales;
GRANT SELECT ON mini_erp.Customer, mini_erp.Product, mini_erp.Transaction TO erp_sales;
GRANT UPDATE (order_status) ON mini_erp.Orders TO erp_sales;
GRANT SELECT ON mini_erp.view_sales_report TO erp_sales;
GRANT SELECT ON mini_erp.view_transaction_summary TO erp_sales;
GRANT SELECT ON mini_erp.view_payment_status TO erp_sales;

-- Inventory: products, suppliers, stock
GRANT SELECT ON mini_erp.Product, mini_erp.Supplier TO erp_inventory;
GRANT UPDATE (stock_quantity) ON mini_erp.Product TO erp_inventory;
GRANT SELECT, INSERT ON mini_erp.Stock_Transaction TO erp_inventory;
GRANT SELECT, INSERT ON mini_erp.Purchase_Order TO erp_inventory;
GRANT UPDATE (po_status) ON mini_erp.Purchase_Order TO erp_inventory;
GRANT SELECT ON mini_erp.view_inventory_status TO erp_inventory;
GRANT SELECT ON mini_erp.view_supplier_supply_records TO erp_inventory;

-- DCL Demo (REVOKE example)
-- GRANT DELETE ON mini_erp.Customer TO erp_sales;   -- Grant
-- REVOKE DELETE ON mini_erp.Customer FROM erp_sales; -- Revoke

-- ============================================================
-- SECTION 7: ADVANCED SELECT QUERIES (for documentation)
-- ============================================================

-- Monthly Revenue Report
-- SELECT TO_CHAR(o.order_date,'Mon YYYY') AS month,
--        COUNT(o.order_id) AS total_orders,
--        SUM(t.amount) AS revenue
-- FROM mini_erp.Orders o
-- JOIN mini_erp.Transaction t ON o.order_id = t.order_id
-- WHERE o.order_status = 'Completed'
-- GROUP BY TO_CHAR(o.order_date,'Mon YYYY'), EXTRACT(MONTH FROM o.order_date)
-- ORDER BY EXTRACT(MONTH FROM o.order_date);

-- Products above average price (Subquery)
-- SELECT name, price FROM mini_erp.Product
-- WHERE price > (SELECT AVG(price) FROM mini_erp.Product);

-- Customers with no orders (Difference)
-- SELECT name FROM mini_erp.Customer
-- WHERE customer_id NOT IN (SELECT DISTINCT customer_id FROM mini_erp.Orders);

-- Payment method breakdown (Window Function)
-- SELECT payment_method, COUNT(*) AS count,
--        ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER(), 2) AS percentage
-- FROM mini_erp.Transaction GROUP BY payment_method;

-- Top customers by spending (HAVING)
-- SELECT c.name, SUM(o.total_amount) AS total_spent
-- FROM mini_erp.Customer c
-- JOIN mini_erp.Orders o ON c.customer_id = o.customer_id
-- GROUP BY c.name
-- HAVING SUM(o.total_amount) > 500000
-- ORDER BY total_spent DESC;

-- ============================================================
-- END OF DATABASE SCRIPT
-- TechZone ERP v2.0 — FAST NUCES Karachi — CS2013
-- ============================================================
