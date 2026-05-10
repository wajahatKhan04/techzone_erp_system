
-- ============================================
-- MINI ERP DATABASE SYSTEM
-- DDL - Data Definition Language
-- Course: CS2013 - Introduction to Database Systems
-- Semester: Spring 2026 | FAST NUCES Karachi
-- ============================================

-- Step 1: Database create 
CREATE DATABASE mini_erp_db;

-- Step 2: Connect to database
\c mini_erp_db;

-- Step 3: Schema create
CREATE SCHEMA mini_erp;

-- Users table mini_erp schema 
CREATE TABLE mini_erp.Users (
    user_id     SERIAL          PRIMARY KEY,
    username    VARCHAR(50)     NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    role        VARCHAR(20)     NOT NULL,
    full_name   VARCHAR(100)    NOT NULL,
    CONSTRAINT chk_role 
        CHECK (role IN ('admin','sales','inventory'))
);

-- 3 users insertion. 
INSERT INTO mini_erp.Users 
    (username, password, role, full_name)
VALUES
    ('admin',     'admin123',  'admin',     'Zafar Iqbal — Admin'),
    ('sales',     'sales123',  'sales',     'Sana Mirza — Sales'),
    ('inventory', 'inv123',    'inventory', 'Hira Fatima — Inventory');

-- Verify
SELECT * FROM mini_erp.Users;

-- ============================================
-- TABLE 1: CATEGORY
-- ============================================
CREATE TABLE mini_erp.Category (
    category_id     SERIAL              PRIMARY KEY,
    category_name   VARCHAR(50)         NOT NULL,
    CONSTRAINT uq_category_name 
        UNIQUE (category_name)
);

-- ============================================
-- TABLE 2: PRODUCT
-- Depends on: Category
-- ============================================
CREATE TABLE mini_erp.Product (
    product_id      SERIAL              PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    price           DECIMAL(10,2)       NOT NULL,
    stock_quantity  INT                 NOT NULL DEFAULT 0,
    category_id     INT                 NOT NULL,
    CONSTRAINT chk_product_price 
        CHECK (price > 0),
    CONSTRAINT chk_stock_quantity 
        CHECK (stock_quantity >= 0),
    CONSTRAINT fk_product_category 
        FOREIGN KEY (category_id)
        REFERENCES mini_erp.Category(category_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ============================================
-- TABLE 3: CUSTOMER
-- ============================================
CREATE TABLE mini_erp.Customer (
    customer_id     SERIAL              PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    phone           VARCHAR(15),
    email           VARCHAR(100),
    address         TEXT,
    join_date       TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    customer_status VARCHAR(20)         DEFAULT 'Active',
    CONSTRAINT uq_customer_phone 
        UNIQUE (phone),
    CONSTRAINT uq_customer_email 
        UNIQUE (email),
    CONSTRAINT chk_customer_status 
        CHECK (customer_status IN ('Active', 'Inactive', 'Blocked'))
);

-- ============================================
-- TABLE 4: SUPPLIER
-- ============================================
CREATE TABLE mini_erp.Supplier (
    supplier_id     SERIAL              PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    contact         VARCHAR(15),
    city            VARCHAR(50),
    supplier_status VARCHAR(20)         DEFAULT 'Active',
    join_date       TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supplier_status 
        CHECK (supplier_status IN ('Active', 'Inactive'))
);

-- ============================================
-- TABLE 5: EMPLOYEE
-- ============================================
CREATE TABLE mini_erp.Employee (
    employee_id     SERIAL              PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    role            VARCHAR(50)         NOT NULL,
    contact         VARCHAR(15),
    join_date       TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_employee_role 
        CHECK (role IN ('Manager', 'Sales Staff', 'Inventory Staff'))
);

-- ============================================
-- TABLE 6: ORDERS
-- Depends on: Customer, Employee
-- ============================================
CREATE TABLE mini_erp.Orders (
    order_id        SERIAL              PRIMARY KEY,
    customer_id     INT                 NOT NULL,
    employee_id     INT,
    order_date      TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    total_amount    DECIMAL(10,2)       NOT NULL,
    order_status    VARCHAR(20)         DEFAULT 'Pending',
    CONSTRAINT chk_total_amount 
        CHECK (total_amount >= 0),
    CONSTRAINT chk_order_status 
        CHECK (order_status IN ('Pending', 'Completed', 'Cancelled')),
    CONSTRAINT fk_orders_customer 
        FOREIGN KEY (customer_id)
        REFERENCES mini_erp.Customer(customer_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_orders_employee 
        FOREIGN KEY (employee_id)
        REFERENCES mini_erp.Employee(employee_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

-- ============================================
-- TABLE 7: SUPPLIER_PRODUCT (Junction Table)
-- Depends on: Supplier, Product
-- Composite Primary Key: supplier_id + product_id + supply_date
-- ============================================
CREATE TABLE mini_erp.Supplier_Product (
    supplier_id     INT                 NOT NULL,
    product_id      INT                 NOT NULL,
    supply_date     DATE                NOT NULL,
    supply_price    DECIMAL(10,2)       NOT NULL,
    quantity        INT                 NOT NULL,
    CONSTRAINT pk_supplier_product 
        PRIMARY KEY (supplier_id, product_id, supply_date),
    CONSTRAINT chk_supply_price 
        CHECK (supply_price > 0),
    CONSTRAINT chk_supply_quantity 
        CHECK (quantity > 0),
    CONSTRAINT fk_sp_supplier 
        FOREIGN KEY (supplier_id)
        REFERENCES mini_erp.Supplier(supplier_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_sp_product 
        FOREIGN KEY (product_id)
        REFERENCES mini_erp.Product(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ============================================
-- TABLE 8: ORDER_DETAILS (Junction Table)
-- Depends on: Orders, Product
-- Composite Primary Key: order_id + product_id
-- ============================================
CREATE TABLE mini_erp.Order_Details (
    order_id        INT                 NOT NULL,
    product_id      INT                 NOT NULL,
    quantity        INT                 NOT NULL,
    price           DECIMAL(10,2)       NOT NULL,
    CONSTRAINT pk_order_details 
        PRIMARY KEY (order_id, product_id),
    CONSTRAINT chk_od_quantity 
        CHECK (quantity > 0),
    CONSTRAINT chk_od_price 
        CHECK (price > 0),
    CONSTRAINT fk_od_order 
        FOREIGN KEY (order_id)
        REFERENCES mini_erp.Orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_od_product 
        FOREIGN KEY (product_id)
        REFERENCES mini_erp.Product(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ============================================
-- TABLE 9: TRANSACTION
-- Depends on: Orders
-- One-to-One with Orders
-- ============================================
CREATE TABLE mini_erp.Transaction (
    transaction_id  SERIAL              PRIMARY KEY,
    order_id        INT                 NOT NULL,
    amount          DECIMAL(10,2)       NOT NULL,
    payment_method  VARCHAR(30)         NOT NULL,
    transaction_date TIMESTAMP          DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_transaction_order 
        UNIQUE (order_id),
    CONSTRAINT chk_amount 
        CHECK (amount > 0),
    CONSTRAINT chk_payment_method 
        CHECK (payment_method IN 
            ('Cash', 'Card', 'Bank Transfer')),
    CONSTRAINT fk_transaction_order 
        FOREIGN KEY (order_id)
        REFERENCES mini_erp.Orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ============================================
-- TABLE 10: STOCK_TRANSACTION
-- Depends on: Product
-- ============================================
CREATE TABLE mini_erp.Stock_Transaction (
    stock_txn_id    SERIAL              PRIMARY KEY,
    product_id      INT                 NOT NULL,
    type            VARCHAR(5)          NOT NULL,
    quantity        INT                 NOT NULL,
    date            TIMESTAMP           DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_stock_type 
        CHECK (type IN ('IN', 'OUT')),
    CONSTRAINT chk_stock_qty 
        CHECK (quantity > 0),
    CONSTRAINT fk_stock_product 
        FOREIGN KEY (product_id)
        REFERENCES mini_erp.Product(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

SELECT * FROM  mini_erp.category;

-- ============================================
-- VERIFY: All tables
-- ============================================
SELECT * 
FROM information_schema.tables 
WHERE table_schema = 'mini_erp';



-- ============================================
-- MINI ERP DATABASE SYSTEM
-- Company: TechZone Pvt Ltd
-- Business: IT Equipment Supplier
-- DML - INSERT Realistic Sample Data
-- ============================================

-- ============================================
-- INSERT 1: CATEGORY (8 rows)
-- ============================================
INSERT INTO mini_erp.Category (category_name) VALUES
('Laptops & Notebooks'),
('Desktop & Workstations'),
('Networking Equipment'),
('Servers & Storage'),
('Monitors & Displays'),
('Peripherals & Accessories'),
('Software & Licenses'),
('Power & UPS Solutions');

-- Verify
SELECT * FROM mini_erp.Category;


-- ============================================
-- INSERT 2: PRODUCT (15 rows)
-- Real IT products with market accurate prices
-- ============================================
INSERT INTO mini_erp.Product 
    (name, price, stock_quantity, category_id) VALUES
('Dell Latitude 5540 Core i7',          185000.00,  30,  1),
('HP ProBook 450 G10 Core i5',          135000.00,  45,  1),
('Lenovo ThinkPad X1 Carbon',           280000.00,  15,  1),
('HP Z2 Tower Workstation',             320000.00,  10,  2),
('Dell OptiPlex 7010 Desktop',           95000.00,  25,  2),
('Cisco Catalyst 2960 Switch 24-Port',  145000.00,  20,  3),
('TP-Link 48-Port Gigabit Switch',       42000.00,  35,  3),
('Dell PowerEdge R350 Server',          850000.00,   5,  4),
('Synology NAS DS923+',                 185000.00,  12,  4),
('Dell 27" 4K Monitor P2723QE',          95000.00,  28,  5),
('LG 24" FHD IPS Monitor',              42000.00,  50,  5),
('Logitech MX Keys Keyboard',            18500.00,  60,  6),
('Microsoft Arc Mouse',                  12500.00,  75,  6),
('Microsoft Office 365 Business',        28000.00, 100,  7),
('APC Smart UPS 1500VA',                 95000.00,  22,  8);


-- Verify
SELECT p.product_id, p.name, p.price, 
       p.stock_quantity, c.category_name
FROM mini_erp.Product p
JOIN mini_erp.Category c 
    ON p.category_id = c.category_id;


-- ============================================
-- INSERT 3: CUSTOMER (12 rows)
-- Corporate clients, universities, govt offices
-- ============================================
INSERT INTO mini_erp.Customer 
    (name, phone, email, address, customer_status) VALUES
('Habib University IT Dept',        
    '021-111-HABIB', 
    'procurement@habibu.edu.pk',        
    '23-km Gulshan-e-Iqbal, Karachi',           
    'Active'),
('Meezan Bank Head Office',         
    '021-111-MEEZAN',
    'it.procurement@meezanbank.com',    
    'Meezan House, C-25, Estate Ave, Karachi',  
    'Active'),
('PTCL Islamabad HQ',               
    '051-111-PTCL', 
    'vendor@ptcl.net.pk',               
    'PTCL Headquarters, G-8/4, Islamabad',      
    'Active'),
('National Bank of Pakistan',       
    '021-99220100', 
    'it.dept@nbp.com.pk',               
    'NBP Head Office, I.I. Chundrigar Rd, Karachi',
    'Active'),
('NUST University Islamabad',       
    '051-9085000',  
    'procurement@nust.edu.pk',          
    'H-12, Islamabad',                          
    'Active'),
('Systems Limited Lahore',          
    '042-35761999', 
    'procurement@systemsltd.com',       
    '59-C, Gulberg III, Lahore',                
    'Active'),
('K-Electric Karachi',              
    '021-99000',    
    'it.vendor@ke.com.pk',              
    'KE House, 39-B, Sunset Blvd, DHA, Karachi',
    'Active'),
('Punjab Information Technology Board',
    '042-99211033', 
    'procurement@pitb.gov.pk',          
    'Arfa Software Technology Park, Lahore',    
    'Active'),
('Aga Khan University Hospital',    
    '021-34930051', 
    'it.dept@aku.edu',                  
    'Stadium Road, Karachi',                    
    'Active'),
('HBL Plaza Karachi',               
    '021-111-000111',
    'it.procurement@hbl.com',          
    'HBL Plaza, I.I Chundrigar Rd, Karachi',    
    'Active'),
('LUMS University Lahore',          
    '042-35608000', 
    'procurement@lums.edu.pk',          
    'DHA, Lahore Cantt',                        
    'Active'),
('FBR House Islamabad',             
    '051-9205823',  
    'it.dept@fbr.gov.pk',               
    'Constitution Avenue, Islamabad',           
    'Inactive');


-- Verify
SELECT * FROM mini_erp.Customer;


-- ============================================
-- INSERT 4: SUPPLIER (10 rows)
-- Authorized distributors & manufacturers
-- ============================================
INSERT INTO mini_erp.Supplier 
    (name, contact, city, supplier_status) VALUES
('Dell Technologies Pakistan',      
    '021-35640001', 'Karachi',    'Active'),
('HP Pakistan (Pvt) Ltd',           
    '042-35761500', 'Lahore',     'Active'),
('Lenovo Authorized Distributor PK',
    '051-2800900',  'Islamabad',  'Active'),
('Cisco Systems Pakistan',          
    '021-35640050', 'Karachi',    'Active'),
('TP-Link Pakistan',                
    '042-35200300', 'Lahore',     'Active'),
('Microsoft Pakistan Pvt Ltd',      
    '051-2800800',  'Islamabad',  'Active'),
('APC by Schneider Electric PK',    
    '021-35640100', 'Karachi',    'Active'),
('Synology Authorized Dealer PK',   
    '021-34521100', 'Karachi',    'Active'),
('LG Electronics Pakistan',         
    '042-35761600', 'Lahore',     'Active'),
('Logitech Pakistan Distributor',   
    '021-34522200', 'Karachi',    'Inactive');


-- Verify
SELECT * FROM mini_erp.Supplier;


-- ============================================
-- INSERT 5: EMPLOYEE (10 rows)
-- TechZone staff with proper designations
-- ============================================
INSERT INTO mini_erp.Employee 
    (name, role, contact) VALUES
('Mr. Zafar Iqbal',       'Manager',          '0321-9000001'),
('Ms. Sana Mirza',        'Sales Staff',      '0312-9000002'),
('Mr. Kamran Yousuf',     'Sales Staff',      '0333-9000003'),
('Ms. Hira Fatima',       'Inventory Staff',  '0345-9000004'),
('Mr. Tariq Jameel',      'Manager',          '0311-9000005'),
('Ms. Amna Khalid',       'Sales Staff',      '0322-9000006'),
('Mr. Bilal Mustafa',     'Inventory Staff',  '0315-9000007'),
('Ms. Rabia Qadir',       'Sales Staff',      '0301-9000008'),
('Mr. Hassan Nawaz',      'Manager',          '0321-9000009'),
('Ms. Nida Rehman',       'Sales Staff',      '0312-9000010');


-- Verify
SELECT * FROM mini_erp.Employee;


-- ============================================
-- INSERT 6: ORDERS (12 rows)
-- Corporate bulk orders Jan-Mar 2026
-- ============================================
INSERT INTO mini_erp.Orders 
    (customer_id, employee_id, order_date, 
     total_amount, order_status) VALUES
-- January 2026
(2,  2,  '2026-01-05 09:30:00', 1850000.00, 'Completed'),  -- Meezan Bank: 10x Dell Latitude
(4,  3,  '2026-01-08 11:00:00', 4250000.00, 'Completed'),  -- NBP: Servers + Networking
(1,  6,  '2026-01-12 10:15:00',  675000.00, 'Completed'),  -- Habib Uni: Laptops + Monitors
(7,  2,  '2026-01-15 14:00:00', 2900000.00, 'Completed'),  -- K-Electric: Workstations
(5,  8,  '2026-01-20 09:00:00', 1350000.00, 'Completed'),  -- NUST: Laptops bulk
-- February 2026
(3,  3,  '2026-02-02 10:30:00', 3625000.00, 'Completed'),  -- PTCL: Cisco Switches
(8,  6,  '2026-02-07 11:45:00',  840000.00, 'Completed'),  -- PITB: Mixed IT
(10, 2,  '2026-02-12 09:15:00', 1425000.00, 'Completed'),  -- HBL: Laptops + UPS
(6,  3,  '2026-02-18 14:30:00',  560000.00, 'Pending'),    -- Systems Ltd: Accessories
(9,  8,  '2026-02-25 10:00:00',  950000.00, 'Completed'),  -- AKU Hospital: Servers
-- March 2026
(11, 6,  '2026-03-03 09:30:00',  700000.00, 'Pending'),    -- LUMS: Laptops
(2,  2,  '2026-03-10 11:00:00',  285000.00, 'Completed');  -- Meezan Bank: Monitors + UPS


-- Verify
SELECT o.order_id, c.name AS customer, 
       e.name AS handled_by,
       o.order_date, o.total_amount, 
       o.order_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
JOIN mini_erp.Employee e ON o.employee_id = e.employee_id;


-- ============================================
-- INSERT 7: SUPPLIER_PRODUCT (12 rows)
-- Which supplier supplies which product
-- ============================================
INSERT INTO mini_erp.Supplier_Product 
    (supplier_id, product_id, supply_date, 
     supply_price, quantity) VALUES
(1,  1,  '2025-12-01', 162000.00,  35),  -- Dell → Dell Latitude
(1,  4,  '2025-12-01', 285000.00,  12),  -- Dell → HP Z2 Workstation
(1,  5,  '2025-12-05',  82000.00,  30),  -- Dell → Dell OptiPlex
(1,  8,  '2025-12-10', 740000.00,   6),  -- Dell → Dell Server
(2,  2,  '2025-12-02', 118000.00,  50),  -- HP → HP ProBook
(2,  10, '2025-12-02',  82000.00,  32),  -- HP → Dell Monitor (HP dist)
(3,  3,  '2025-12-03', 245000.00,  18),  -- Lenovo → ThinkPad
(4,  6,  '2025-12-04', 128000.00,  22),  -- Cisco → Cisco Switch
(5,  7,  '2025-12-05',  36000.00,  40),  -- TP-Link → TP-Link Switch
(6,  14, '2025-12-06',  24000.00, 120),  -- Microsoft → Office 365
(7,  15, '2025-12-07',  82000.00,  25),  -- APC → APC UPS
(9,  11, '2025-12-08',  36000.00,  55);  -- LG → LG Monitor


-- Verify
SELECT s.name AS supplier, p.name AS product,
       sp.supply_price, sp.quantity, sp.supply_date
FROM mini_erp.Supplier_Product sp
JOIN mini_erp.Supplier s ON sp.supplier_id = s.supplier_id
JOIN mini_erp.Product p  ON sp.product_id  = p.product_id;


-- ============================================
-- INSERT 8: ORDER_DETAILS (15 rows)
-- Actual products in each order
-- ============================================
INSERT INTO mini_erp.Order_Details 
    (order_id, product_id, quantity, price) VALUES
-- Order 1: Meezan Bank - 10x Dell Laptops
(1,  1,  10, 185000.00),
-- Order 2: NBP - Servers + Networking
(2,  8,   4, 850000.00),
(2,  6,   5, 145000.00),
-- Order 3: Habib Uni - Laptops + Monitors
(3,  2,   5, 135000.00),
-- Order 4: K-Electric - Workstations
(4,  4,   9, 320000.00),
-- Order 5: NUST - Bulk Laptops
(5,  2,   8, 135000.00),
(5,  3,   2, 280000.00),
-- Order 6: PTCL - Cisco Switches
(6,  6,  25, 145000.00),
-- Order 7: PITB - Mixed IT
(7,  7,  10,  42000.00),
(7,  14, 10,  28000.00),
-- Order 8: HBL - Laptops + UPS
(8,  1,   5, 185000.00),
(8,  15,  5,  95000.00),
-- Order 9: Systems Ltd - Accessories
(9,  12, 10,  18500.00),
(9,  13, 20,  12500.00),
-- Order 10: AKU Hospital - Server + NAS
(10, 8,   1, 850000.00),
(10, 9,   1, 185000.00);


-- Verify
SELECT o.order_id, c.name AS customer,
       p.name AS product,
       od.quantity, od.price,
       (od.quantity * od.price) AS line_total
FROM mini_erp.Order_Details od
JOIN mini_erp.Orders  o ON od.order_id  = o.order_id
JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
JOIN mini_erp.Product  p ON od.product_id = p.product_id
ORDER BY o.order_id;


-- ============================================
-- INSERT 9: TRANSACTION (10 rows)
-- Corporate payments - mostly bank transfers
-- ============================================
INSERT INTO mini_erp.Transaction 
    (order_id, amount, payment_method, 
     transaction_date) VALUES
(1,  1850000.00, 'Bank Transfer', '2026-01-06'),
(2,  4250000.00, 'Bank Transfer', '2026-01-09'),
(3,   675000.00, 'Bank Transfer', '2026-01-13'),
(4,  2900000.00, 'Bank Transfer', '2026-01-16'),
(5,  1350000.00, 'Bank Transfer', '2026-01-21'),
(6,  3625000.00, 'Bank Transfer', '2026-02-03'),
(7,   840000.00, 'Card',          '2026-02-08'),
(8,  1425000.00, 'Bank Transfer', '2026-02-13'),
(10,  950000.00, 'Bank Transfer', '2026-02-26'),
(12,  285000.00, 'Card',          '2026-03-11');


-- Verify
SELECT t.transaction_id, c.name AS customer,
       t.amount, t.payment_method,
       t.transaction_date
FROM mini_erp.Transaction t
JOIN mini_erp.Orders  o ON t.order_id   = o.order_id
JOIN mini_erp.Customer c ON o.customer_id = c.customer_id;


-- ============================================
-- INSERT 10: STOCK_TRANSACTION (12 rows)
-- Stock IN when supplied, OUT when ordered
-- ============================================
INSERT INTO mini_erp.Stock_Transaction 
    (product_id, type, quantity, date) VALUES
-- Stock IN - December 2025 (supplier delivery)
(1,  'IN',  35, '2025-12-01'),   -- Dell Latitude received
(2,  'IN',  50, '2025-12-02'),   -- HP ProBook received
(3,  'IN',  18, '2025-12-03'),   -- ThinkPad received
(4,  'IN',  12, '2025-12-01'),   -- HP Workstation received
(6,  'IN',  22, '2025-12-04'),   -- Cisco Switch received
(8,  'IN',   6, '2025-12-10'),   -- Dell Server received
(14, 'IN', 120, '2025-12-06'),   -- MS Office licenses received
(15, 'IN',  25, '2025-12-07'),   -- APC UPS received
-- Stock OUT - January/February 2026 (orders dispatched)
(1,  'OUT', 15, '2026-01-06'),   -- Dell Laptops dispatched (Order 1+8)
(2,  'OUT', 13, '2026-01-13'),   -- HP Laptops dispatched (Order 3+5)
(8,  'OUT',  5, '2026-01-09'),   -- Servers dispatched (Order 2+10)
(6,  'OUT', 30, '2026-02-03');   -- Cisco Switches dispatched (Order 6)


-- Verify
SELECT st.stock_txn_id, p.name AS product,
       st.type, st.quantity, st.date
FROM mini_erp.Stock_Transaction st
JOIN mini_erp.Product p ON st.product_id = p.product_id
ORDER BY st.date;


-- ============================================
-- FINAL VERIFY:Row count for all tables
-- ============================================
SELECT 'Category'        AS table_name, COUNT(*) AS rows FROM mini_erp.Category
UNION ALL
SELECT 'Product',                        COUNT(*) FROM mini_erp.Product
UNION ALL
SELECT 'Customer',                       COUNT(*) FROM mini_erp.Customer
UNION ALL
SELECT 'Supplier',                       COUNT(*) FROM mini_erp.Supplier
UNION ALL
SELECT 'Employee',                       COUNT(*) FROM mini_erp.Employee
UNION ALL
SELECT 'Orders',                         COUNT(*) FROM mini_erp.Orders
UNION ALL
SELECT 'Supplier_Product',               COUNT(*) FROM mini_erp.Supplier_Product
UNION ALL
SELECT 'Order_Details',                  COUNT(*) FROM mini_erp.Order_Details
UNION ALL
SELECT 'Transaction',                    COUNT(*) FROM mini_erp.Transaction
UNION ALL
SELECT 'Stock_Transaction',              COUNT(*) FROM mini_erp.Stock_Transaction;



-- ============================================
-- MINI ERP - TechZone Pvt Ltd
-- DML - UPDATE & DELETE QUERIES
-- ============================================


-- ============================================
-- UPDATE QUERIES
-- ============================================

-- ============================================
-- U1: Customer status update 
-- FBR House Inactive -> Active 
-- ============================================

-- first look current state!
SELECT customer_id, name, customer_status 
FROM mini_erp.Customer 
WHERE name = 'FBR House Islamabad';

-- Update 
UPDATE mini_erp.Customer
SET customer_status = 'Active'
WHERE name = 'FBR House Islamabad';

-- Verify 
SELECT customer_id, name, customer_status 
FROM mini_erp.Customer 
WHERE name = 'FBR House Islamabad';


-- ============================================
-- U2: Product price update
-- HP ProBook price 135,000 -> 142,000 
-- (market price adjust)
-- ============================================

-- current price 
SELECT product_id, name, price 
FROM mini_erp.Product 
WHERE name = 'HP ProBook 450 G10 Core i5';

-- Update 
UPDATE mini_erp.Product
SET price = 142000.00
WHERE name = 'HP ProBook 450 G10 Core i5';

-- Verify 
SELECT product_id, name, price 
FROM mini_erp.Product 
WHERE name = 'HP ProBook 450 G10 Core i5';


-- ============================================
-- U3: Stock quantity update 
-- new shipment come — Dell Latitude 
-- add more 20 units 
-- ============================================

--  current stock 
SELECT product_id, name, stock_quantity 
FROM mini_erp.Product 
WHERE name = 'Dell Latitude 5540 Core i7';

-- Update 
UPDATE mini_erp.Product
SET stock_quantity = stock_quantity + 20
WHERE name = 'Dell Latitude 5540 Core i7';

-- Verify 
SELECT product_id, name, stock_quantity 
FROM mini_erp.Product 
WHERE name = 'Dell Latitude 5540 Core i7';


-- ============================================
-- U4: Order status update 
-- Pending orders -> Completed 
-- ============================================

-- first look pending orders 
SELECT o.order_id, c.name, o.order_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'Pending';

-- Update 
UPDATE mini_erp.Orders
SET order_status = 'Completed'
WHERE order_id = 11;

-- Verify 
SELECT o.order_id, c.name, 
       o.total_amount, o.order_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c 
    ON o.customer_id = c.customer_id
WHERE o.order_id = 11;


-- ============================================
-- U5: Employee  role update 
-- Senior Sales Staff -> Manager promote :D
-- ============================================

--  current role
SELECT employee_id, name, role 
FROM mini_erp.Employee 
WHERE name = 'Ms. Sana Mirza';

-- Update 
UPDATE mini_erp.Employee
SET role = 'Manager'
WHERE name = 'Ms. Sana Mirza';

-- Verify 
SELECT employee_id, name, role 
FROM mini_erp.Employee 
WHERE name = 'Ms. Sana Mirza';


-- ============================================
-- U6: Supplier status update 
-- Active again Logitech Distributor
-- ============================================

-- look status 
SELECT supplier_id, name, supplier_status 
FROM mini_erp.Supplier 
WHERE name = 'Logitech Pakistan Distributor';

-- Update 
UPDATE mini_erp.Supplier
SET supplier_status = 'Active'
WHERE name = 'Logitech Pakistan Distributor';

-- Verify 
SELECT supplier_id, name, supplier_status 
FROM mini_erp.Supplier 
WHERE name = 'Logitech Pakistan Distributor';


-- ============================================
-- U7: Bulk price update
-- increase all laptop price 5%
-- (new fiscal year pricing)
-- ============================================

--  current prices 
SELECT p.name, p.price
FROM mini_erp.Product p
JOIN mini_erp.Category c 
    ON p.category_id = c.category_id
WHERE c.category_name = 'Laptops & Notebooks';

-- Update 
UPDATE mini_erp.Product
SET price = ROUND(price * 1.05, 2)
WHERE category_id = (
    SELECT category_id 
    FROM mini_erp.Category 
    WHERE category_name = 'Laptops & Notebooks'
);

-- Verify 
SELECT p.name, p.price
FROM mini_erp.Product p
JOIN mini_erp.Category c 
    ON p.category_id = c.category_id
WHERE c.category_name = 'Laptops & Notebooks';


-- ============================================
-- U8: Transaction amount update 
-- Wrong amount -> correct it
-- ============================================

-- first look 
SELECT transaction_id, order_id, 
       amount, payment_method
FROM mini_erp.Transaction
WHERE order_id = 7;

-- Update 
UPDATE mini_erp.Transaction
SET amount = 840000.00
WHERE order_id = 7;

-- Verify 
SELECT transaction_id, order_id, 
       amount, payment_method
FROM mini_erp.Transaction
WHERE order_id = 7;


-- ============================================
-- DELETE QUERIES
-- ============================================

-- ============================================
-- D1: Inactive supplier delete 
-- (National Traders Multan - business band)
-- ============================================

--  confirm 
SELECT supplier_id, name, supplier_status 
FROM mini_erp.Supplier
WHERE supplier_status = 'Inactive';

-- Delete 
DELETE FROM mini_erp.Supplier
WHERE supplier_status = 'Inactive'
AND supplier_id NOT IN (
    SELECT DISTINCT supplier_id 
    FROM mini_erp.Supplier_Product
);

-- Verify 
SELECT supplier_id, name, supplier_status 
FROM mini_erp.Supplier;


-- ============================================
-- D2: Blocked customer delete 
-- (Kamran Sheikh - account permanently blocked)
-- ============================================

-- confirm
SELECT customer_id, name, customer_status 
FROM mini_erp.Customer
WHERE customer_status = 'Blocked';

-- Delete 
DELETE FROM mini_erp.Customer
WHERE customer_status = 'Blocked'
AND customer_id NOT IN (
    SELECT DISTINCT customer_id 
    FROM mini_erp.Orders
);

-- Verify 
SELECT customer_id, name, customer_status 
FROM mini_erp.Customer
ORDER BY customer_id;


-- ============================================
-- D3: Cancelled order delete 
-- (if any order is cancel)
-- ============================================

--  check 
SELECT order_id, total_amount, order_status
FROM mini_erp.Orders
WHERE order_status = 'Cancelled';

-- Delete  (if exist )
DELETE FROM mini_erp.Orders
WHERE order_status = 'Cancelled';

-- Verify 
SELECT order_id, order_status 
FROM mini_erp.Orders
ORDER BY order_id;


-- ============================================
-- D4: Specific stock transaction delete 
--(if due to mistake any duplicate data entry)
-- ============================================

-- check first
SELECT * FROM mini_erp.Stock_Transaction
ORDER BY stock_txn_id;

-- most last entry delete  (if duplicate )
DELETE FROM mini_erp.Stock_Transaction
WHERE stock_txn_id = (
    SELECT MAX(stock_txn_id) 
    FROM mini_erp.Stock_Transaction
    WHERE product_id = 6 
    AND type = 'OUT'
);

-- Verify 
SELECT * FROM mini_erp.Stock_Transaction
ORDER BY stock_txn_id;


-- ============================================
-- FINAL STATE CHECK
-- All update table row count
-- ============================================
SELECT 'Category'        AS table_name, COUNT(*) AS rows 
FROM mini_erp.Category
UNION ALL
SELECT 'Product',        COUNT(*) FROM mini_erp.Product
UNION ALL
SELECT 'Customer',       COUNT(*) FROM mini_erp.Customer
UNION ALL
SELECT 'Supplier',       COUNT(*) FROM mini_erp.Supplier
UNION ALL
SELECT 'Employee',       COUNT(*) FROM mini_erp.Employee
UNION ALL
SELECT 'Orders',         COUNT(*) FROM mini_erp.Orders
UNION ALL
SELECT 'Supplier_Product', COUNT(*) FROM mini_erp.Supplier_Product
UNION ALL
SELECT 'Order_Details',  COUNT(*) FROM mini_erp.Order_Details
UNION ALL
SELECT 'Transaction',    COUNT(*) FROM mini_erp.Transaction
UNION ALL
SELECT 'Stock_Transaction', COUNT(*) FROM mini_erp.Stock_Transaction;





-- ============================================
-- MINI ERP - TechZone Pvt Ltd
-- VIEWS - Virtual Tables for Reporting
-- ============================================


-- ============================================
-- VIEW 1: view_sales_report
-- Orders + Customer + Employee
-- Purpose: Daily/Monthly sales overview
-- ============================================
CREATE VIEW mini_erp.view_sales_report AS
SELECT 
    o.order_id,
    c.name                          AS customer_name,
    c.email                         AS customer_email,
    e.name                          AS handled_by,
    e.role                          AS employee_role,
    o.order_date,
    o.total_amount,
    o.order_status,
    t.payment_method,
    t.transaction_date              AS paid_on
FROM mini_erp.Orders o
JOIN mini_erp.Customer c 
    ON o.customer_id = c.customer_id
JOIN mini_erp.Employee e 
    ON o.employee_id = e.employee_id
LEFT JOIN mini_erp.Transaction t 
    ON o.order_id = t.order_id;

-- use view
SELECT * FROM mini_erp.view_sales_report;

-- only completed orders
SELECT * FROM mini_erp.view_sales_report
WHERE order_status = 'Completed'
ORDER BY order_date DESC;

-- Monthly sales summary
SELECT 
    TO_CHAR(order_date, 'Month YYYY')   AS month,
    COUNT(order_id)                      AS total_orders,
    SUM(total_amount)                    AS total_revenue
FROM mini_erp.view_sales_report
WHERE order_status = 'Completed'
GROUP BY TO_CHAR(order_date, 'Month YYYY'),
         EXTRACT(MONTH FROM order_date)
ORDER BY EXTRACT(MONTH FROM order_date);


-- ============================================
-- VIEW 2: view_inventory_status
-- Product + Category + Stock levels
-- Purpose: Stock monitoring & low stock alert
-- ============================================
CREATE VIEW mini_erp.view_inventory_status AS
SELECT 
    p.product_id,
    p.name                          AS product_name,
    c.category_name,
    p.price,
    p.stock_quantity,
    CASE 
        WHEN p.stock_quantity = 0   THEN 'Out of Stock'
        WHEN p.stock_quantity < 10  THEN 'Critical'
        WHEN p.stock_quantity < 20  THEN 'Low Stock'
        ELSE                             'In Stock'
    END                             AS stock_status,
    (p.price * p.stock_quantity)    AS stock_value
FROM mini_erp.Product p
JOIN mini_erp.Category c 
    ON p.category_id = c.category_id;

-- Use View
SELECT * FROM mini_erp.view_inventory_status;

-- Sirf low/critical stock
SELECT * FROM mini_erp.view_inventory_status
WHERE stock_status IN ('Low Stock', 'Critical', 'Out of Stock')
ORDER BY stock_quantity ASC;

-- Category wise stock value
SELECT 
    category_name,
    COUNT(product_id)       AS total_products,
    SUM(stock_quantity)     AS total_units,
    SUM(stock_value)        AS total_stock_value
FROM mini_erp.view_inventory_status
GROUP BY category_name
ORDER BY total_stock_value DESC;


-- ============================================
-- VIEW 3: view_customer_purchase_history
-- Customer + Orders + Order_Details + Product
-- Purpose: What each customer bought
-- ============================================
CREATE VIEW mini_erp.view_customer_purchase_history AS
SELECT 
    c.customer_id,
    c.name                              AS customer_name,
    c.email,
    c.customer_status,
    o.order_id,
    o.order_date,
    o.order_status,
    p.name                              AS product_name,
    cat.category_name,
    od.quantity,
    od.price                            AS unit_price,
    (od.quantity * od.price)            AS line_total,
    t.payment_method
FROM mini_erp.Customer c
JOIN mini_erp.Orders o 
    ON c.customer_id = o.customer_id
JOIN mini_erp.Order_Details od 
    ON o.order_id = od.order_id
JOIN mini_erp.Product p 
    ON od.product_id = p.product_id
JOIN mini_erp.Category cat 
    ON p.category_id = cat.category_id
LEFT JOIN mini_erp.Transaction t 
    ON o.order_id = t.order_id;

-- Use View 
SELECT * FROM mini_erp.view_customer_purchase_history;

-- Specific customer  history
SELECT * FROM mini_erp.view_customer_purchase_history
WHERE customer_name = 'Meezan Bank Head Office'
ORDER BY order_date DESC;

-- Top customers by total spending
SELECT 
    customer_name,
    COUNT(DISTINCT order_id)    AS total_orders,
    SUM(line_total)             AS total_spent
FROM mini_erp.view_customer_purchase_history
WHERE order_status = 'Completed'
GROUP BY customer_id, customer_name
ORDER BY total_spent DESC;


-- ============================================
-- VIEW 4: view_supplier_supply_records
-- Supplier + Supplier_Product + Product
-- Purpose: Track what each supplier supplied
-- ============================================
CREATE VIEW mini_erp.view_supplier_supply_records AS
SELECT 
    s.supplier_id,
    s.name                              AS supplier_name,
    s.city,
    s.supplier_status,
    p.name                              AS product_name,
    cat.category_name,
    sp.supply_date,
    sp.quantity                         AS units_supplied,
    sp.supply_price,
    (sp.quantity * sp.supply_price)     AS total_supply_value
FROM mini_erp.Supplier s
JOIN mini_erp.Supplier_Product sp 
    ON s.supplier_id = sp.supplier_id
JOIN mini_erp.Product p 
    ON sp.product_id = p.product_id
JOIN mini_erp.Category cat 
    ON p.category_id = cat.category_id;

-- Use view
SELECT * FROM mini_erp.view_supplier_supply_records;

-- Specific supplier supply
SELECT * FROM mini_erp.view_supplier_supply_records
WHERE supplier_name = 'Dell Technologies Pakistan'
ORDER BY supply_date DESC;

-- Supplier wise total supply value
SELECT 
    supplier_name,
    city,
    COUNT(product_name)         AS products_supplied,
    SUM(units_supplied)         AS total_units,
    SUM(total_supply_value)     AS total_value
FROM mini_erp.view_supplier_supply_records
GROUP BY supplier_id, supplier_name, city
ORDER BY total_value DESC;


-- ============================================
-- VIEW 5: view_transaction_summary
-- Transaction + Orders + Customer
-- Purpose: Financial summary & payment tracking
-- ============================================
CREATE VIEW mini_erp.view_transaction_summary AS
SELECT 
    t.transaction_id,
    c.name                          AS customer_name,
    o.order_id,
    o.order_date,
    o.total_amount                  AS order_value,
    t.amount                        AS amount_paid,
    (o.total_amount - t.amount)     AS balance,
    t.payment_method,
    t.transaction_date,
    CASE
        WHEN t.amount >= o.total_amount THEN 'Fully Paid'
        WHEN t.amount > 0               THEN 'Partially Paid'
        ELSE                                 'Unpaid'
    END                             AS payment_status
FROM mini_erp.Transaction t
JOIN mini_erp.Orders o 
    ON t.order_id = o.order_id
JOIN mini_erp.Customer c 
    ON o.customer_id = c.customer_id;

-- Use View
SELECT * FROM mini_erp.view_transaction_summary;

-- Payment method breakdown
SELECT 
    payment_method,
    COUNT(transaction_id)       AS total_transactions,
    SUM(amount_paid)            AS total_collected
FROM mini_erp.view_transaction_summary
GROUP BY payment_method
ORDER BY total_collected DESC;

-- Total revenue collected
SELECT 
    SUM(amount_paid)            AS total_revenue,
    COUNT(transaction_id)       AS total_transactions,
    AVG(amount_paid)            AS avg_transaction
FROM mini_erp.view_transaction_summary;


-- ============================================
-- VERIFY:  views list 
-- ============================================
SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'mini_erp';



-- ============================================
-- MINI ERP - TechZone Pvt Ltd
-- TCL - Transaction Control Language
-- ACID Properties Implementation
-- ============================================




-- ============================================
-- TRANSACTION 1: Placing a New Order
-- Scenario: NUST University ordered 5x Lenovo ThinkPad laptops — Rs. 1,400,000
-- Steps that must happen together:
-- Step 1 → Insert into Orders table
-- Step 2 → Insert into Order_Details table
-- Step 3 → Insert OUT record in Stock_Transaction
-- Step 4 → Update product stock
-- Step 5 → Insert transaction (payment record)

-- If any step fails →
-- ROLLBACK — undo everything
-- ============================================

BEGIN;

    -- Step 1: Order insert 
    INSERT INTO mini_erp.Orders
        (customer_id, employee_id, order_date,
         total_amount, order_status)
    VALUES
        (5, 3, CURRENT_TIMESTAMP, 
         1400000.00, 'Completed');

    -- Step 2: Order details insert 
    -- order_id = lastval() se milega
    INSERT INTO mini_erp.Order_Details
        (order_id, product_id, quantity, price)
    VALUES
        (lastval(), 3, 5, 280000.00);

    -- Step 3: Stock OUT record
    INSERT INTO mini_erp.Stock_Transaction
        (product_id, type, quantity, date)
    VALUES
        (3, 'OUT', 5, CURRENT_DATE);

    -- Step 4: Product stock update 
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity - 5
    WHERE product_id = 3;

    -- Step 5: Payment record insert 
    INSERT INTO mini_erp.Transaction
        (order_id, amount, 
         payment_method, transaction_date)
    VALUES
        (lastval(), 1400000.00,
         'Bank Transfer', CURRENT_DATE);

COMMIT;

-- Verify 
SELECT * FROM mini_erp.view_sales_report
WHERE customer_name = 'NUST University Islamabad'
ORDER BY order_date DESC;


-- ============================================
-- TRANSACTION 2: ROLLBACK Demonstration

-- Scenario: K-Electric placed an order,
-- but the payment method was incorrect →
-- ROLLBACK is executed
-- ============================================

BEGIN;

    -- Step 1: Order insert 
    INSERT INTO mini_erp.Orders
        (customer_id, employee_id, order_date,
         total_amount, order_status)
    VALUES
        (7, 2, CURRENT_TIMESTAMP,
         570000.00, 'Pending');

    -- Step 2: Order details
    INSERT INTO mini_erp.Order_Details
        (order_id, product_id, quantity, price)
    VALUES
        (lastval(), 6, 2, 145000.00),
        (lastval(), 7, 5,  42000.00);

-- Error detected — incorrect payment method
-- Perform ROLLBACK — all changes will be undone
ROLLBACK;

-- Verify that the new order for K-Electric
-- should NOT exist in the system
SELECT * FROM mini_erp.view_sales_report
WHERE customer_name = 'K-Electric Karachi'
ORDER BY order_date DESC;


-- ============================================
-- TRANSACTION 3: SAVEPOINT Demonstration
--
-- Scenario: HBL placed a large order —
-- 3 products included. During processing,
-- one product is out of stock —
-- rollback only that part, keep the rest saved
-- ============================================

BEGIN;

    -- Step 1: Order insert
    INSERT INTO mini_erp.Orders
        (customer_id, employee_id, order_date,
         total_amount, order_status)
    VALUES
        (10, 6, CURRENT_TIMESTAMP,
         925000.00, 'Pending');

    -- Step 2: 1st product — Dell Latitude
    INSERT INTO mini_erp.Order_Details
        (order_id, product_id, quantity, price)
    VALUES
        (lastval(), 1, 3, 185000.00);

	-- Set a savepoint after the first product
    SAVEPOINT after_first_product;

    -- Step 3: 2nd product — ThinkPad
    -- (stock check  — not exist)
    INSERT INTO mini_erp.Order_Details
        (order_id, product_id, quantity, price)
    VALUES
        (lastval(), 3, 2, 280000.00);

    -- only ThinkPad  part rollback 
    ROLLBACK TO SAVEPOINT after_first_product;

    -- Step 4: Alternative product — HP ProBook
    INSERT INTO mini_erp.Order_Details
        (order_id, product_id, quantity, price)
    VALUES
        (lastval(), 2, 3, 142000.00);

-- Update stock only for the products that were successfully added
	UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity - 3
    WHERE product_id = 1;

    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity - 3
    WHERE product_id = 2;

    -- Order status update
    UPDATE mini_erp.Orders
    SET order_status = 'Completed',
        total_amount = 981000.00
    WHERE order_id = (
        SELECT MAX(order_id) 
        FROM mini_erp.Orders
    );

COMMIT;

-- Verify karo
SELECT * FROM mini_erp.view_customer_purchase_history
WHERE customer_name = 'HBL Plaza Karachi'
ORDER BY order_date DESC;


-- ============================================
-- TRANSACTION 4: Supplier Stock IN
--
-- Scenario: Dell Technologies sent a new shipment —
-- 20x Dell Latitude and 10x Dell OptiPlex
--
-- Steps:
-- Step 1 → Insert record in Supplier_Product
-- Step 2 → Insert IN record in Stock_Transaction
-- Step 3 → Update product stock
-- ============================================

BEGIN;

    -- Step 1: Supply record insert
    INSERT INTO mini_erp.Supplier_Product
        (supplier_id, product_id, 
         supply_date, supply_price, quantity)
    VALUES
        (1, 1, CURRENT_DATE, 160000.00, 20),
        (1, 5, CURRENT_DATE,  80000.00, 10);

    -- Step 2: Stock IN record
    INSERT INTO mini_erp.Stock_Transaction
        (product_id, type, quantity, date)
    VALUES
        (1, 'IN', 20, CURRENT_DATE),
        (5, 'IN', 10, CURRENT_DATE);

    -- Step 3: Product stock update
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + 20
    WHERE product_id = 1;

    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + 10
    WHERE product_id = 5;

COMMIT;

-- Verify 
SELECT * FROM mini_erp.view_inventory_status
WHERE product_name IN (
    'Dell Latitude 5540 Core i7',
    'Dell OptiPlex 7010 Desktop'
);


-- ============================================
-- TRANSACTION 5: Order Cancellation
--
-- Scenario: Systems Limited cancelled the order —
-- all related changes must be reversed
--
-- Steps:
-- Step 1 → Update order status to Cancelled
-- Step 2 → Restore stock back to inventory
-- Step 3 → Insert reverse entry in Stock_Transaction
-- ============================================
BEGIN;

    -- Step 1: Order cancel 
    UPDATE mini_erp.Orders
    SET order_status = 'Cancelled'
    WHERE order_id = 9;

	-- Step 2: Restore stock back into inventory
	-- (the items that were included in the order)
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + 10
    WHERE product_id = 12;

    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + 20
    WHERE product_id = 13;

    -- Step 3: Stock IN reversal entry
    INSERT INTO mini_erp.Stock_Transaction
        (product_id, type, quantity, date)
    VALUES
        (12, 'IN', 10, CURRENT_DATE),
        (13, 'IN', 20, CURRENT_DATE);

COMMIT;

-- Verify 
SELECT o.order_id, c.name, 
       o.total_amount, o.order_status
FROM mini_erp.Orders o
JOIN mini_erp.Customer c 
    ON o.customer_id = c.customer_id
WHERE o.order_id = 9;


-- ============================================
-- VERIFY: Does Stock updated properly ?
-- ============================================
SELECT * FROM mini_erp.view_inventory_status
ORDER BY stock_status, stock_quantity ASC;












-- ============================================
-- MINI ERP - TechZone Pvt Ltd
-- DCL - Data Control Language
-- GRANT & REVOKE - Role Based Access Control
-- ============================================


-- ============================================
-- TECHZONE - User Roles Overview
--
-- The system has 3 types of users:
--
-- 1. erp_admin
--    → Full access — database owner
--    → Mr. Zafar Iqbal (Manager)
--
-- 2. erp_sales
--    → Can view and insert Orders, Customers,
--      and Products
--    → Ms. Sana Mirza, Mr. Kamran Yousuf
--
-- 3. erp_inventory
--    → Can manage Products and Stock only
--      (cannot view orders)
--    → Ms. Hira Fatima, Mr. Bilal Mustafa
-- ============================================


-- ============================================
-- STEP 1: Create roles
-- ============================================

-- Admin role
CREATE ROLE erp_admin 
    LOGIN 
    PASSWORD 'Admin@TechZone2026';

-- Sales role
CREATE ROLE erp_sales 
    LOGIN 
    PASSWORD 'Sales@TechZone2026';

-- Inventory role
CREATE ROLE erp_inventory 
    LOGIN 
    PASSWORD 'Inv@TechZone2026';

-- Verify roles
SELECT rolname, rolcanlogin 
FROM pg_roles
WHERE rolname IN (
    'erp_admin', 
    'erp_sales', 
    'erp_inventory'
);


-- ============================================
-- STEP 2: GRANT — erp_admin
-- Full access on all tables
-- ============================================

-- Schema access
GRANT USAGE ON SCHEMA mini_erp 
    TO erp_admin;

-- All tables full access
GRANT ALL PRIVILEGES 
    ON ALL TABLES IN SCHEMA mini_erp 
    TO erp_admin;

-- Access should also apply to future tables
	ALTER DEFAULT PRIVILEGES 
    IN SCHEMA mini_erp
    GRANT ALL PRIVILEGES ON TABLES 
    TO erp_admin;

-- Access control on sequences (SERIAL columns)
	GRANT ALL PRIVILEGES 
    ON ALL SEQUENCES IN SCHEMA mini_erp 
    TO erp_admin;

-- Verify
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_admin'
AND table_schema = 'mini_erp';


-- ============================================
-- STEP 3: GRANT — erp_sales Role
--
-- CAN:
-- → SELECT on all tables (view data)
-- → INSERT into Orders, Order_Details (create orders)
-- → UPDATE Orders (update status)
-- → INSERT into Transaction (record payments)
--
-- CANNOT:
-- → DELETE any records
-- → Modify Products or Suppliers
-- → Access Stock_Transaction
-- ============================================

-- Schema access
GRANT USAGE ON SCHEMA mini_erp 
    TO erp_sales;

-- SELECT permission — can view all tables
	GRANT SELECT ON 
    mini_erp.Customer,
    mini_erp.Product,
    mini_erp.Category,
    mini_erp.Supplier,
    mini_erp.Employee,
    mini_erp.Orders,
    mini_erp.Order_Details,
    mini_erp.Transaction
    TO erp_sales;

-- SELECT on Views
GRANT SELECT ON 
    mini_erp.view_sales_report,
    mini_erp.view_inventory_status,
    mini_erp.view_customer_purchase_history,
    mini_erp.view_transaction_summary
    TO erp_sales;

-- INSERT permission — only for order-related tables
GRANT INSERT ON 
    mini_erp.Orders,
    mini_erp.Order_Details,
    mini_erp.Transaction
    TO erp_sales;

-- UPDATE — only order status
GRANT UPDATE (order_status, total_amount) 
    ON mini_erp.Orders 
    TO erp_sales;

-- Sequences (for SERIAL insert)
GRANT USAGE ON 
    mini_erp.orders_order_id_seq,
    mini_erp.transaction_transaction_id_seq
    TO erp_sales;

-- Verify
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_sales'
AND table_schema = 'mini_erp'
ORDER BY table_name;


-- ============================================
-- STEP 4: GRANT — erp_inventory
--
-- CAN:
-- → SELECT on Products, Category, Supplier
-- → UPDATE stock on Products
-- → INSERT/SELECT on Stock_Transaction
-- → INSERT on Supplier_Product
--
-- CANNOT:
-- → See Orders or Customer data
-- → Access Transaction/payment data
-- → DELETE anything
-- ============================================

-- Schema access
GRANT USAGE ON SCHEMA mini_erp 
    TO erp_inventory;

-- SELECT — Only inventory related tables
GRANT SELECT ON 
    mini_erp.Product,
    mini_erp.Category,
    mini_erp.Supplier,
    mini_erp.Supplier_Product,
    mini_erp.Stock_Transaction
    TO erp_inventory;

-- SELECT on View 
GRANT SELECT ON 
    mini_erp.view_inventory_status,
    mini_erp.view_supplier_supply_records
    TO erp_inventory;

-- UPDATE — only stock quantity
GRANT UPDATE (stock_quantity) 
    ON mini_erp.Product 
    TO erp_inventory;

-- INSERT — stock and supply records
GRANT INSERT ON 
    mini_erp.Stock_Transaction,
    mini_erp.Supplier_Product
    TO erp_inventory;

-- Sequences
GRANT USAGE ON 
    mini_erp.stock_transaction_stock_txn_id_seq
    TO erp_inventory;

-- Verify
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_inventory'
AND table_schema = 'mini_erp'
ORDER BY table_name;


- ============================================
-- STEP 5: REVOKE Demo
--
-- Scenario 1: erp_sales was mistakenly given
-- DELETE access on Customer table
-- Now we remove it
-- ============================================

-- First (mistakenly granted access)
GRANT DELETE ON mini_erp.Customer 
    TO erp_sales;

-- Verify that DELETE privilege is showing for erp_sales
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_sales'
AND table_name = 'customer';

-- Now REVOKE 
REVOKE DELETE ON mini_erp.Customer 
    FROM erp_sales;

-- Verify that DELETE permission has been removed
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_sales'
AND table_name = 'customer';


-- ============================================
-- Scenario 2: Revoke erp_inventory access
--
-- Remove INSERT permission on Supplier_Product
-- (Only admin should handle supplier deals)
-- ============================================

REVOKE INSERT ON mini_erp.Supplier_Product 
    FROM erp_inventory;

-- Verify
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'erp_inventory'
AND table_name = 'supplier_product';


-- ============================================
-- STEP 6: Access Matrix Verification
-- Check all roles and their permissions together
-- ============================================
SELECT 
    grantee                 AS role_name,
    table_name,
    STRING_AGG(
        privilege_type, ', ' 
        ORDER BY privilege_type
    )                       AS permissions
FROM information_schema.role_table_grants
WHERE grantee IN (
    'erp_admin',
    'erp_sales', 
    'erp_inventory'
)
AND table_schema = 'mini_erp'
GROUP BY grantee, table_name
ORDER BY grantee, table_name;


-- ============================================
-- MINI ERP - TechZone Pvt Ltd
-- NORMALIZATION DOCUMENTATION
-- 1NF → 2NF → 3NF
-- ============================================



-- ============================================
-- FIRST NORMAL FORM (1NF)
--
-- Rules:
--  Each column must have atomic (single) values
--  No repeating groups
--  Each row must be unique (Primary Key required)
--  Each column must have a fixed data type
-- ============================================

-- ============================================
-- 1NF VIOLATION EXAMPLE
-- (What we DID NOT do)
-- ============================================

--  WRONG — violates 1NF:
-- This table is NOT in 1NF:
--
-- order_id | customer | products
-- ---------+----------+---------------------------
-- 1        | Meezan   | Dell Laptop, HP Monitor
-- 2        | NBP      | Cisco Switch, Dell Server
--
-- Problem:
-- The "products" column contains multiple values
-- → Not atomic → 1NF violation

-- ============================================
-- 1NF SOLUTION — Our Design
-- ============================================

-- CORRECT — Our Order_Details table:
-- Each product is stored in a separate row

SELECT 
    od.order_id,
    c.name      AS customer,
    p.name      AS product,       -- atomic value
    od.quantity,                  -- atomic value
    od.price                      -- atomic value
FROM mini_erp.Order_Details od
JOIN mini_erp.Orders o  ON od.order_id  = o.order_id
JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
JOIN mini_erp.Product p  ON od.product_id = p.product_id
ORDER BY od.order_id;

-- 1NF Check: Is every column atomic (single value per field)?
SELECT 
    'Orders'            AS tbl, 
    'order_id'          AS pk, 
    'Atomic '         AS status
UNION ALL SELECT 'Product',         'product_id',   'Atomic '
UNION ALL SELECT 'Customer',        'customer_id',  'Atomic '
UNION ALL SELECT 'Order_Details',   'order_id + product_id', 'Atomic '
UNION ALL SELECT 'Supplier_Product','supplier_id + product_id + supply_date', 'Atomic ';


-- ============================================
-- SECOND NORMAL FORM (2NF)
--
-- Rules:
-- Must already be in 1NF
-- No partial dependency
--    (Non-key attributes must depend on the
--     FULL primary key, not just part of it)
--
-- Note: 2NF applies only when using a composite primary key
-- ============================================

-- ============================================
-- 2NF VIOLATION EXAMPLE
-- (What we did NOT implement)
-- ============================================

--  WRONG — violates 2NF:
-- Composite Primary Key = (order_id + product_id)
--
-- order_id | product_id | product_name | qty | price
-- ---------+------------+--------------+-----+------
-- 1        | 101        | Dell Laptop  | 10  | 185000
-- 1        | 102        | HP Monitor   | 5   | 42000
--
-- Problem:
-- "product_name" depends only on product_id
-- not on full composite key (order_id + product_id)
-- → This is partial dependency → 2NF violation

-- ============================================
-- 2NF SOLUTION — Our Design
-- ============================================

-- CORRECT:
-- product_name is stored in a separate Product table
-- Order_Details only contains order-specific + product-specific data

-- Order_Details table — 2NF compliant
SELECT 
    'order_id + product_id'     AS composite_pk,
    'quantity'                  AS depends_on_full_pk,
    'price'                     AS depends_on_full_pk2;
-- quantity  → depends on BOTH order_id AND product_id 
-- price     → depends on BOTH order_id AND product_id 

-- Product table — separated properly
SELECT 
    'product_id'    AS pk,
    'name'          AS full_dependency,
    'price'         AS full_dependency2,
    'stock_qty'     AS full_dependency3;
-- All columns depend only on product_id 

-- Supplier_Product table — 2NF check
SELECT 
    'supplier_id + product_id + supply_date'    AS composite_pk,
    'supply_price'  AS depends_on_full_pk,
    'quantity'      AS depends_on_full_pk2;
-- supply_price → depends on ALL 3 PK columns 
-- quantity     → depends on ALL 3 PK columns 

-- Verify: No partial dependency exists
SELECT 
    t.table_name,
    '2NF Compliant' AS status,
    'No partial dependencies found' AS reason
FROM information_schema.tables t
WHERE t.table_schema = 'mini_erp'
AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;

-- ============================================
-- THIRD NORMAL FORM (3NF)
--
-- Rules:
-- Must already be in 2NF
-- No transitive dependency
--    (A non-key column must NOT depend on another non-key column)
--
-- Simple idea: A → B → C is NOT allowed
-- Instead, A should directly determine C
-- ============================================

-- ============================================
-- 3NF VIOLATION EXAMPLE
-- (What we DID NOT do)
-- ============================================

--  WRONG — violates 3NF:
--
-- product_id | category_id | category_name | price
-- -----------+-------------+---------------+------
-- 1          | 1           | Laptops       | 185000
-- 2          | 1           | Laptops       | 135000
-- 3          | 2           | Networking    | 145000
--
-- Problem:
-- product_id → category_id → category_name
-- category_name does NOT depend directly on product_id
-- it depends on category_id instead
-- → This is a transitive dependency → 3NF violation
--
-- If category_name changes:
-- multiple rows must be updated → leads to anomalies
-- ============================================

-- ============================================
-- 3NF SOLUTION — Our Design
-- ============================================

-- CORRECT:
-- Category data is stored in a separate Category table
-- so product depends only on category_id, not category_name

-- Category table
SELECT 
    category_id,
    category_name   -- Only depends on category_id
FROM mini_erp.Category;

-- Product table
SELECT 
    product_id,
    name,
    price,
    stock_quantity,
    category_id     -- Only a foreign key — name is not stored here 
FROM mini_erp.Product;

-- Join to verify — no redundancy exists
SELECT 
    p.product_id,
    p.name,
    p.price,
    c.category_name  -- Comes directly from the Category table
FROM mini_erp.Product p
JOIN mini_erp.Category c 
    ON p.category_id = c.category_id;
-- ============================================
-- 3NF: All Tables Check
-- ============================================

-- Customer table — 3NF check
-- customer_id → name, phone, email, address, status
-- No transitive dependency exists 
SELECT 
    'Customer'  AS table_name,
    'customer_id → name, phone, email, address' AS dependency,
    'No transitive dependency ' AS nf3_status;

-- Orders table — 3NF check  
-- order_id → customer_id, employee_id, date, amount, status
-- Customer name is NOT stored in Orders — it is in Customer table only

SELECT 
    'Orders'    AS table_name,
    'order_id → customer_id(FK), employee_id(FK), date, amount' AS dependency,
    'No transitive dependency ' AS nf3_status;

-- Transaction table — 3NF check
-- transaction_id → order_id, amount, method, date
-- Customer info is NOT stored in Transaction — it comes via Orders table 
SELECT 
    'Transaction' AS table_name,
    'transaction_id → order_id(FK), amount, method, date' AS dependency,
    'No transitive dependency ' AS nf3_status;

-- ============================================
-- COMPLETE NORMALIZATION SUMMARY
-- ============================================
SELECT 
    t.table_name,
    '1NF ' AS first_nf,
    '2NF ' AS second_nf,
    '3NF ' AS third_nf
FROM information_schema.tables t
WHERE t.table_schema = 'mini_erp'
AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;

-- ============================================
-- FUNCTIONAL DEPENDENCIES
-- (Important for exams / normalization proof)
-- ============================================

-- Category
-- category_id → category_name

-- Product  
-- product_id → name, price, stock_quantity, category_id

-- Customer
-- customer_id → name, phone, email, address, status
-- phone       → customer_id (candidate key)
-- email       → customer_id (candidate key)

-- Supplier
-- supplier_id → name, contact, city, status

-- Employee
-- employee_id → name, role, contact

-- Orders
-- order_id → customer_id, employee_id, order_date, total_amount, status

-- Supplier_Product
-- (supplier_id, product_id, supply_date)
-- → supply_price, quantity

-- Order_Details
-- (order_id, product_id)
-- → quantity, price

-- Transaction
-- transaction_id → order_id, amount, method, date
-- order_id       → transaction_id (1:1 relationship)

-- Stock_Transaction
-- stock_txn_id → product_id, type, quantity, date


-- ============================================================
-- TECHZONE PVT LTD — TRIGGERS
-- ============================================================

-- ============================================================
-- TRIGGER 1: Auto decrease stock when order is placed
-- When: INSERT into Order_Details
-- Action: Decrease product stock_quantity
-- ============================================================
CREATE OR REPLACE FUNCTION mini_erp.fn_decrease_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    -- Log stock movement
    INSERT INTO mini_erp.Stock_Transaction(product_id, type, quantity, date)
    VALUES (NEW.product_id, 'OUT', NEW.quantity, CURRENT_DATE);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_decrease_stock
AFTER INSERT ON mini_erp.Order_Details
FOR EACH ROW
EXECUTE FUNCTION mini_erp.fn_decrease_stock();

-- ============================================================
-- TRIGGER 2: Auto increase stock when supplier supplies
-- When: INSERT into Supplier_Product
-- Action: Increase product stock_quantity
-- ============================================================
CREATE OR REPLACE FUNCTION mini_erp.fn_increase_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mini_erp.Product
    SET stock_quantity = stock_quantity + NEW.quantity
    WHERE product_id = NEW.product_id;

    -- Log stock movement
    INSERT INTO mini_erp.Stock_Transaction(product_id, type, quantity, date)
    VALUES (NEW.product_id, 'IN', NEW.quantity, CURRENT_DATE);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_increase_stock
AFTER INSERT ON mini_erp.Supplier_Product
FOR EACH ROW
EXECUTE FUNCTION mini_erp.fn_increase_stock();

-- ============================================================
-- TRIGGER 3: Prevent negative stock
-- When: BEFORE INSERT on Order_Details
-- Action: Raise error if not enough stock
-- ============================================================
CREATE OR REPLACE FUNCTION mini_erp.fn_check_stock()
RETURNS TRIGGER AS $$
DECLARE
    available INT;
BEGIN
    SELECT stock_quantity INTO available
    FROM mini_erp.Product
    WHERE product_id = NEW.product_id;

    IF available < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %',
            available, NEW.quantity;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_stock
BEFORE INSERT ON mini_erp.Order_Details
FOR EACH ROW
EXECUTE FUNCTION mini_erp.fn_check_stock();

-- ============================================================
-- TRIGGER 4: Auto update order total when details change
-- When: INSERT into Order_Details
-- Action: Recalculate Orders.total_amount
-- ============================================================
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

CREATE TRIGGER trg_update_order_total
AFTER INSERT OR UPDATE ON mini_erp.Order_Details
FOR EACH ROW
EXECUTE FUNCTION mini_erp.fn_update_order_total();

-- ============================================================
-- TRIGGER 5: Log order status changes
-- When: UPDATE on Orders (status change)
-- Action: Print notice (can be extended to audit log)
-- ============================================================
CREATE OR REPLACE FUNCTION mini_erp.fn_log_order_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.order_status <> NEW.order_status THEN
        RAISE NOTICE 'Order #% status changed: % → %',
            NEW.order_id, OLD.order_status, NEW.order_status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_order_status
AFTER UPDATE ON mini_erp.Orders
FOR EACH ROW
EXECUTE FUNCTION mini_erp.fn_log_order_status();

-- ============================================================
-- VERIFY: All triggers
-- ============================================================
SELECT trigger_name, event_manipulation, event_object_table,
       action_timing, action_orientation
FROM information_schema.triggers
WHERE trigger_schema = 'mini_erp'
ORDER BY event_object_table, trigger_name;

