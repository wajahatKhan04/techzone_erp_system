"""
================================================================
TechZone ERP — Automated Quality Assurance Test Suite
================================================================
Course  : CS2013 — Introduction to Database Systems
Program : BS FinTech — FAST NUCES Karachi
Members : Muhammad Wajahat Khan (24K-5554)
          Muhammad Haider Hasnain (24K-5589)
================================================================
HOW TO RUN:
    1. Make sure app.py is running: python app.py
    2. Open new terminal in project folder
    3. Run: python test_techzone.py
================================================================
"""

import requests
import json
import sys
import time

# ── CONFIG ────────────────────────────────────────────────────
BASE_URL = "http://localhost:5000"
TIMEOUT  = 10

# ── COLORS FOR TERMINAL OUTPUT ────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── TEST COUNTERS ─────────────────────────────────────────────
passed   = 0
failed   = 0
warnings = 0
results  = []

# ── HELPER FUNCTIONS ──────────────────────────────────────────
def print_header(title):
    print(f"\n{BLUE}{BOLD}{'='*60}{RESET}")
    print(f"{BLUE}{BOLD}  {title}{RESET}")
    print(f"{BLUE}{BOLD}{'='*60}{RESET}")

def print_section(title):
    print(f"\n{CYAN}{BOLD}── {title} {'─'*(50-len(title))}{RESET}")

def test_pass(name, detail=""):
    global passed
    passed += 1
    results.append(('PASS', name))
    detail_str = f" ({detail})" if detail else ""
    print(f"  {GREEN}✅ PASS{RESET}  {name}{YELLOW}{detail_str}{RESET}")

def test_fail(name, detail=""):
    global failed
    failed += 1
    results.append(('FAIL', name))
    detail_str = f" → {detail}" if detail else ""
    print(f"  {RED}❌ FAIL{RESET}  {name}{RED}{detail_str}{RESET}")

def test_warn(name, detail=""):
    global warnings
    warnings += 1
    results.append(('WARN', name))
    detail_str = f" ({detail})" if detail else ""
    print(f"  {YELLOW}⚠️  WARN{RESET}  {name}{YELLOW}{detail_str}{RESET}")

def get_session(username, password):
    """Create a logged-in session and return it."""
    s = requests.Session()
    try:
        r = s.post(f"{BASE_URL}/api/login",
                   json={"username": username, "password": password},
                   timeout=TIMEOUT)
        if r.status_code == 200 and r.json().get("success"):
            return s
    except Exception:
        pass
    return None

# ══════════════════════════════════════════════════════════════
# TEST SECTION 1: SERVER CONNECTIVITY
# ══════════════════════════════════════════════════════════════
def test_connectivity():
    print_section("1. Server Connectivity")
    try:
        r = requests.get(f"{BASE_URL}/login", timeout=TIMEOUT)
        if r.status_code == 200:
            test_pass("Server is running on localhost:5000")
        else:
            test_fail("Server response", f"Status {r.status_code}")
    except requests.ConnectionError:
        test_fail("Server not reachable", "Make sure python app.py is running!")
        print(f"\n  {RED}⛔ Cannot connect to server. Start app first:{RESET}")
        print(f"  {YELLOW}   python app.py{RESET}\n")
        sys.exit(1)
    except Exception as e:
        test_fail("Server connectivity", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 2: AUTHENTICATION
# ══════════════════════════════════════════════════════════════
def test_authentication():
    print_section("2. Authentication & Login")

    # Test 1: Valid admin login
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "admin", "password": "admin123"},
                         timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Admin login with correct credentials", f"Role: {d.get('role')}")
        else:
            test_fail("Admin login", d.get("error", "Unknown error"))
    except Exception as e:
        test_fail("Admin login", str(e))

    # Test 2: Valid sales login
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "sales", "password": "sales123"},
                         timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Sales login with correct credentials", f"Role: {d.get('role')}")
        else:
            test_fail("Sales login", d.get("error", ""))
    except Exception as e:
        test_fail("Sales login", str(e))

    # Test 3: Valid inventory login
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "inventory", "password": "inv123"},
                         timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Inventory login with correct credentials", f"Role: {d.get('role')}")
        else:
            test_fail("Inventory login", d.get("error", ""))
    except Exception as e:
        test_fail("Inventory login", str(e))

    # Test 4: Wrong password
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "admin", "password": "wrongpassword"},
                         timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 401 and not d.get("success"):
            test_pass("Wrong password correctly rejected", "401 Unauthorized")
        else:
            test_fail("Wrong password should be rejected", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Wrong password test", str(e))

    # Test 5: Wrong username
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "hacker", "password": "hack123"},
                         timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 401 and not d.get("success"):
            test_pass("Non-existent username correctly rejected", "401 Unauthorized")
        else:
            test_fail("Non-existent username should be rejected", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Non-existent username test", str(e))

    # Test 6: Empty credentials
    try:
        r = requests.post(f"{BASE_URL}/api/login",
                         json={"username": "", "password": ""},
                         timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Empty credentials correctly rejected")
        else:
            test_fail("Empty credentials should be rejected")
    except Exception as e:
        test_fail("Empty credentials test", str(e))

    # Test 7: Unauthenticated access to protected route
    try:
        r = requests.get(f"{BASE_URL}/api/customers", timeout=TIMEOUT)
        if r.status_code == 401:
            test_pass("Protected route blocks unauthenticated access", "401 returned")
        else:
            test_fail("Protected route should return 401", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Unauthenticated access test", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 3: ROLE-BASED ACCESS CONTROL
# ══════════════════════════════════════════════════════════════
def test_rbac():
    print_section("3. Role-Based Access Control (RBAC)")

    # Sales session
    sales = get_session("sales", "sales123")
    # Inventory session
    inv = get_session("inventory", "inv123")

    if not sales:
        test_fail("Sales session creation failed — skipping RBAC tests")
        return
    if not inv:
        test_fail("Inventory session creation failed — skipping RBAC tests")
        return

    # Test: Sales cannot access suppliers (inventory only)
    try:
        r = sales.get(f"{BASE_URL}/api/suppliers", timeout=TIMEOUT)
        if r.status_code == 403:
            test_pass("Sales role blocked from Suppliers API", "403 Access Denied")
        else:
            test_fail("Sales should NOT access Suppliers", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Sales→Suppliers RBAC", str(e))

    # Test: Inventory cannot access orders
    try:
        r = inv.get(f"{BASE_URL}/api/orders", timeout=TIMEOUT)
        if r.status_code == 403:
            test_pass("Inventory role blocked from Orders API", "403 Access Denied")
        else:
            test_fail("Inventory should NOT access Orders", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Inventory→Orders RBAC", str(e))

    # Test: Inventory cannot delete customers
    try:
        r = inv.delete(f"{BASE_URL}/api/customers/999", timeout=TIMEOUT)
        if r.status_code == 403:
            test_pass("Inventory role blocked from deleting customers", "403 Access Denied")
        else:
            test_fail("Inventory should NOT delete customers", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Inventory→Delete Customer RBAC", str(e))

    # Test: Sales cannot access audit log (admin only)
    try:
        r = sales.get(f"{BASE_URL}/api/audit-log", timeout=TIMEOUT)
        if r.status_code == 403:
            test_pass("Sales role blocked from Audit Log", "403 Access Denied")
        else:
            test_fail("Sales should NOT access Audit Log", f"Got {r.status_code}")
    except Exception as e:
        test_fail("Sales→Audit Log RBAC", str(e))

    # Test: Admin can access everything
    admin = get_session("admin", "admin123")
    if admin:
        try:
            r = admin.get(f"{BASE_URL}/api/audit-log", timeout=TIMEOUT)
            if r.status_code == 200:
                test_pass("Admin can access Audit Log", "200 OK")
            else:
                test_fail("Admin should access Audit Log", f"Got {r.status_code}")
        except Exception as e:
            test_fail("Admin→Audit Log", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 4: CUSTOMER CRUD
# ══════════════════════════════════════════════════════════════
def test_customers():
    print_section("4. Customer Management (CRUD)")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed — skipping customer tests")
        return

    created_id = None

    # Test: Get all customers
    try:
        r = admin.get(f"{BASE_URL}/api/customers", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get all customers", f"{len(d['data'])} customers found")
        else:
            test_fail("Get all customers", d.get("error", ""))
    except Exception as e:
        test_fail("Get customers", str(e))

    # Test: Add valid customer
    try:
        payload = {
            "name": "QA Test Company Pvt Ltd",
            "phone": "021-12345678",
            "email": "qa.test@techzone.pk",
            "address": "Test Street, Karachi",
            "customer_status": "Active"
        }
        r = admin.post(f"{BASE_URL}/api/customers",
                      json=payload, timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Add valid customer", d.get("message", ""))
            # Get the new ID
            all_c = admin.get(f"{BASE_URL}/api/customers", timeout=TIMEOUT).json()
            for c in all_c["data"]:
                if c["email"] == "qa.test@techzone.pk":
                    created_id = c["customer_id"]
                    break
        else:
            test_fail("Add valid customer", d.get("error", ""))
    except Exception as e:
        test_fail("Add customer", str(e))

    # Test: Add customer with invalid email
    try:
        r = admin.post(f"{BASE_URL}/api/customers",
                      json={"name": "Test", "email": "not-an-email",
                            "customer_status": "Active"},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Invalid email correctly rejected", d.get("error", ""))
        else:
            test_fail("Invalid email should be rejected")
    except Exception as e:
        test_fail("Invalid email validation", str(e))

    # Test: Add customer with invalid phone
    try:
        r = admin.post(f"{BASE_URL}/api/customers",
                      json={"name": "Test", "phone": "abc-invalid",
                            "customer_status": "Active"},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Invalid phone correctly rejected", d.get("error", ""))
        else:
            test_fail("Invalid phone should be rejected")
    except Exception as e:
        test_fail("Invalid phone validation", str(e))

    # Test: Add customer with empty name
    try:
        r = admin.post(f"{BASE_URL}/api/customers",
                      json={"name": "", "customer_status": "Active"},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Empty name correctly rejected", d.get("error", ""))
        else:
            test_fail("Empty name should be rejected")
    except Exception as e:
        test_fail("Empty name validation", str(e))

    # Test: Update customer
    if created_id:
        try:
            r = admin.put(f"{BASE_URL}/api/customers/{created_id}",
                         json={"name": "QA Test Company UPDATED",
                               "email": "qa.test@techzone.pk",
                               "customer_status": "Inactive"},
                         timeout=TIMEOUT)
            d = r.json()
            if r.status_code == 200 and d.get("success"):
                test_pass("Update customer", d.get("message", ""))
            else:
                test_fail("Update customer", d.get("error", ""))
        except Exception as e:
            test_fail("Update customer", str(e))

    # Test: Delete customer (no orders — should succeed)
    if created_id:
        try:
            r = admin.delete(f"{BASE_URL}/api/customers/{created_id}",
                            timeout=TIMEOUT)
            d = r.json()
            if r.status_code == 200 and d.get("success"):
                test_pass("Delete customer with no orders", d.get("message", ""))
            else:
                test_fail("Delete customer", d.get("error", ""))
        except Exception as e:
            test_fail("Delete customer", str(e))

    # Test: Delete customer WITH orders (should fail safely)
    try:
        r = admin.delete(f"{BASE_URL}/api/customers/1", timeout=TIMEOUT)
        d = r.json()
        if not d.get("success") and "order" in d.get("error", "").lower():
            test_pass("Delete customer with orders correctly blocked",
                     d.get("error", ""))
        else:
            test_warn("Delete customer with orders", "Check if customer 1 has orders")
    except Exception as e:
        test_fail("Safe delete customer", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 5: PRODUCT MANAGEMENT
# ══════════════════════════════════════════════════════════════
def test_products():
    print_section("5. Product Management")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    created_id = None

    # Test: Get all products
    try:
        r = admin.get(f"{BASE_URL}/api/products", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get all products", f"{len(d['data'])} products found")
        else:
            test_fail("Get products", d.get("error", ""))
    except Exception as e:
        test_fail("Get products", str(e))

    # Test: Add product with valid data
    try:
        # Get a category ID first
        cats = admin.get(f"{BASE_URL}/api/categories", timeout=TIMEOUT).json()
        cat_id = cats["data"][0]["category_id"] if cats.get("data") else 1

        r = admin.post(f"{BASE_URL}/api/products",
                      json={"name": "QA Test Laptop",
                            "price": 99999,
                            "stock_quantity": 10,
                            "category_id": cat_id},
                      timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Add valid product", d.get("message", ""))
            prods = admin.get(f"{BASE_URL}/api/products", timeout=TIMEOUT).json()
            for p in prods["data"]:
                if p["name"] == "QA Test Laptop":
                    created_id = p["product_id"]
                    break
        else:
            test_fail("Add valid product", d.get("error", ""))
    except Exception as e:
        test_fail("Add product", str(e))

    # Test: Negative price rejected
    try:
        r = admin.post(f"{BASE_URL}/api/products",
                      json={"name": "Bad Product", "price": -500,
                            "stock_quantity": 10, "category_id": 1},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Negative price correctly rejected", d.get("error", ""))
        else:
            test_fail("Negative price should be rejected")
    except Exception as e:
        test_fail("Negative price validation", str(e))

    # Test: Zero price rejected
    try:
        r = admin.post(f"{BASE_URL}/api/products",
                      json={"name": "Zero Price", "price": 0,
                            "stock_quantity": 10, "category_id": 1},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Zero price correctly rejected", d.get("error", ""))
        else:
            test_fail("Zero price should be rejected")
    except Exception as e:
        test_fail("Zero price validation", str(e))

    # Test: Negative stock rejected
    try:
        r = admin.post(f"{BASE_URL}/api/products",
                      json={"name": "Neg Stock", "price": 1000,
                            "stock_quantity": -5, "category_id": 1},
                      timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Negative stock correctly rejected", d.get("error", ""))
        else:
            test_fail("Negative stock should be rejected")
    except Exception as e:
        test_fail("Negative stock validation", str(e))

    # Test: Delete test product
    if created_id:
        try:
            r = admin.delete(f"{BASE_URL}/api/products/{created_id}",
                            timeout=TIMEOUT)
            d = r.json()
            if d.get("success"):
                test_pass("Delete test product", d.get("message", ""))
            else:
                test_fail("Delete test product", d.get("error", ""))
        except Exception as e:
            test_fail("Delete product", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 6: ORDERS & TRANSACTIONS
# ══════════════════════════════════════════════════════════════
def test_orders():
    print_section("6. Orders & Transactions")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    # Test: Get all orders
    try:
        r = admin.get(f"{BASE_URL}/api/orders", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get all orders", f"{len(d['data'])} orders found")
        else:
            test_fail("Get orders", d.get("error", ""))
    except Exception as e:
        test_fail("Get orders", str(e))

    # Test: Get order details
    try:
        r = admin.get(f"{BASE_URL}/api/orders/1", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get order details (Order #1)",
                     f"{len(d['data'])} line items")
        else:
            test_fail("Get order details", d.get("error", ""))
    except Exception as e:
        test_fail("Get order details", str(e))

    # Test: Update order status — valid
    try:
        r = admin.put(f"{BASE_URL}/api/orders/12/status",
                     json={"status": "Completed"}, timeout=TIMEOUT)
        d = r.json()
        if d.get("success"):
            test_pass("Update order status to Completed", d.get("message", ""))
            # Reset back to Pending
            admin.put(f"{BASE_URL}/api/orders/12/status",
                     json={"status": "Pending"}, timeout=TIMEOUT)
        else:
            test_warn("Update order status", d.get("error", "Check if order 12 exists"))
    except Exception as e:
        test_fail("Update order status", str(e))

    # Test: Invalid order status rejected
    try:
        r = admin.put(f"{BASE_URL}/api/orders/1/status",
                     json={"status": "InvalidStatus"}, timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Invalid order status correctly rejected", d.get("error", ""))
        else:
            test_fail("Invalid status should be rejected")
    except Exception as e:
        test_fail("Invalid order status", str(e))

    # Test: Get transactions
    try:
        r = admin.get(f"{BASE_URL}/api/transactions", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get all transactions", f"{len(d['data'])} transactions found")
        else:
            test_fail("Get transactions", d.get("error", ""))
    except Exception as e:
        test_fail("Get transactions", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 7: SUPPLIERS
# ══════════════════════════════════════════════════════════════
def test_suppliers():
    print_section("7. Supplier Management")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    created_id = None

    # Test: Get all suppliers
    try:
        r = admin.get(f"{BASE_URL}/api/suppliers", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Get all suppliers", f"{len(d['data'])} suppliers found")
        else:
            test_fail("Get suppliers", d.get("error", ""))
    except Exception as e:
        test_fail("Get suppliers", str(e))

    # Test: Add valid supplier
    try:
        r = admin.post(f"{BASE_URL}/api/suppliers",
                      json={"name": "QA Test Supplier",
                            "contact": "021-99999999",
                            "city": "Karachi",
                            "supplier_status": "Active"},
                      timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Add valid supplier", d.get("message", ""))
            supps = admin.get(f"{BASE_URL}/api/suppliers", timeout=TIMEOUT).json()
            for s in supps["data"]:
                if s["name"] == "QA Test Supplier":
                    created_id = s["supplier_id"]
                    break
        else:
            test_fail("Add supplier", d.get("error", ""))
    except Exception as e:
        test_fail("Add supplier", str(e))

    # Test: Delete supplier with no records
    if created_id:
        try:
            r = admin.delete(f"{BASE_URL}/api/suppliers/{created_id}",
                            timeout=TIMEOUT)
            d = r.json()
            if d.get("success"):
                test_pass("Delete supplier with no supply records",
                         d.get("message", ""))
            else:
                test_fail("Delete supplier", d.get("error", ""))
        except Exception as e:
            test_fail("Delete supplier", str(e))

    # Test: Delete supplier WITH records (should fail safely)
    try:
        r = admin.delete(f"{BASE_URL}/api/suppliers/1", timeout=TIMEOUT)
        d = r.json()
        if not d.get("success"):
            test_pass("Delete supplier with records correctly blocked",
                     d.get("error", ""))
        else:
            test_warn("Supplier delete safety", "Check if supplier 1 has supply records")
    except Exception as e:
        test_fail("Safe delete supplier", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 8: INNOVATION FEATURES
# ══════════════════════════════════════════════════════════════
def test_innovations():
    print_section("8. Innovation Features")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    # Test: Profit Margins API
    try:
        r = admin.get(f"{BASE_URL}/api/profit-margins", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            summary = d.get("summary", {})
            test_pass("Profit Margins API working",
                     f"Overall margin: {summary.get('overall_margin', '?')}%")
            # Validate structure
            if d.get("data") and len(d["data"]) > 0:
                first = d["data"][0]
                required_keys = ["product_name","sale_price","avg_supply_cost",
                                "profit_per_unit","margin_percent","health"]
                missing = [k for k in required_keys if k not in first]
                if not missing:
                    test_pass("Profit margin data structure correct",
                             "All required fields present")
                else:
                    test_fail("Profit margin structure", f"Missing: {missing}")
        else:
            test_fail("Profit Margins API", d.get("error", ""))
    except Exception as e:
        test_fail("Profit Margins API", str(e))

    # Test: AI Reorder Suggestions API
    try:
        r = admin.get(f"{BASE_URL}/api/ai/reorder-suggestions", timeout=30)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            ai_powered = d.get("ai_powered", False)
            mode = "AI-Powered" if ai_powered else "Rule-Based fallback"
            test_pass(f"AI Reorder API working ({mode})",
                     f"{len(d['data'])} products analyzed")
            # Check structure
            if d.get("data") and len(d["data"]) > 0:
                first = d["data"][0]
                required = ["product_name","current_stock","urgency",
                           "recommended_order_qty","reason"]
                missing = [k for k in required if k not in first]
                if not missing:
                    test_pass("AI reorder data structure correct",
                             "All required fields present")
                else:
                    test_fail("AI reorder structure", f"Missing: {missing}")
            # Check urgency values are valid
            valid_urgencies = {"Critical","Warning","OK"}
            invalid = [d2["urgency"] for d2 in d["data"]
                      if d2.get("urgency") not in valid_urgencies]
            if not invalid:
                test_pass("All urgency levels are valid values",
                         "Critical/Warning/OK only")
            else:
                test_fail("Invalid urgency values found", str(invalid[:3]))
        else:
            test_fail("AI Reorder API", d.get("error", ""))
    except Exception as e:
        test_fail("AI Reorder API", str(e))

    # Test: Stock Movements API
    try:
        inv = get_session("inventory", "inv123")
        r = inv.get(f"{BASE_URL}/api/stock-movements", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Stock Movements API working",
                     f"{len(d['data'])} movements found")
        else:
            test_fail("Stock Movements API", d.get("error", ""))
    except Exception as e:
        test_fail("Stock Movements API", str(e))

    # Test: Purchase Orders API
    try:
        inv = get_session("inventory", "inv123")
        r = inv.get(f"{BASE_URL}/api/purchase-orders", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Purchase Orders API working",
                     f"{len(d['data'])} POs found")
        else:
            test_fail("Purchase Orders API", d.get("error", ""))
    except Exception as e:
        test_fail("Purchase Orders API", str(e))

    # Test: Audit Log API (admin only)
    try:
        r = admin.get(f"{BASE_URL}/api/audit-log", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Audit Log API working",
                     f"{len(d['data'])} log entries found")
        else:
            test_fail("Audit Log API", d.get("error", ""))
    except Exception as e:
        test_fail("Audit Log API", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 9: REPORTS (DATABASE VIEWS)
# ══════════════════════════════════════════════════════════════
def test_reports():
    print_section("9. Reports (Database Views)")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    report_types = [
        ("sales",        "view_sales_report"),
        ("inventory",    "view_inventory_status"),
        ("customers",    "view_customer_purchase_history"),
        ("transactions", "view_transaction_summary"),
        ("suppliers",    "view_supplier_supply_records"),
    ]

    for rtype, view_name in report_types:
        try:
            r = admin.get(f"{BASE_URL}/api/reports/{rtype}", timeout=TIMEOUT)
            d = r.json()
            if r.status_code == 200 and d.get("success"):
                test_pass(f"Report: {view_name}",
                         f"{len(d['data'])} rows returned")
            else:
                test_fail(f"Report: {view_name}", d.get("error", "View may not exist"))
        except Exception as e:
            test_fail(f"Report: {view_name}", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 10: DASHBOARD
# ══════════════════════════════════════════════════════════════
def test_dashboard():
    print_section("10. Dashboard & KPIs")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    # Test: Default dashboard
    try:
        r = admin.get(f"{BASE_URL}/api/dashboard", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            data = d["data"]
            required = ["total_revenue","orders","active_customers",
                       "low_stock","active_suppliers","monthly_revenue","top_products"]
            missing = [k for k in required if k not in data]
            if not missing:
                test_pass("Dashboard returns all KPIs",
                         f"Revenue: {data['total_revenue']:,.0f} PKR")
            else:
                test_fail("Dashboard missing KPIs", str(missing))
        else:
            test_fail("Dashboard API", d.get("error", ""))
    except Exception as e:
        test_fail("Dashboard API", str(e))

    # Test: Period filter — 7 days
    try:
        r = admin.get(f"{BASE_URL}/api/dashboard?period=7", timeout=TIMEOUT)
        d = r.json()
        if d.get("success") and "period_revenue" in d["data"]:
            test_pass("Dashboard period filter (7 days)",
                     f"Period revenue: {d['data']['period_revenue']:,.0f} PKR")
        else:
            test_fail("Dashboard period filter", "period_revenue missing")
    except Exception as e:
        test_fail("Dashboard period filter", str(e))

    # Test: Period filter — 30 days
    try:
        r = admin.get(f"{BASE_URL}/api/dashboard?period=30", timeout=TIMEOUT)
        d = r.json()
        if d.get("success") and d["data"].get("period_days") == 30:
            test_pass("Dashboard period filter (30 days)", "period_days=30 confirmed")
        else:
            test_warn("Dashboard 30-day filter", "Check period_days in response")
    except Exception as e:
        test_fail("Dashboard 30-day filter", str(e))

    # Test: Notifications
    try:
        r = admin.get(f"{BASE_URL}/api/notifications", timeout=TIMEOUT)
        d = r.json()
        if r.status_code == 200 and d.get("success"):
            test_pass("Notifications API working",
                     f"{d.get('count', 0)} notifications")
        else:
            test_fail("Notifications API", d.get("error", ""))
    except Exception as e:
        test_fail("Notifications API", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 11: CSV EXPORTS
# ══════════════════════════════════════════════════════════════
def test_exports():
    print_section("11. CSV Export")

    admin = get_session("admin", "admin123")
    if not admin:
        test_fail("Admin session failed")
        return

    exports = ["customers", "products", "orders", "transactions", "suppliers"]

    for export_type in exports:
        try:
            r = admin.get(f"{BASE_URL}/api/export/{export_type}",
                         timeout=TIMEOUT)
            if (r.status_code == 200 and
                "text/csv" in r.headers.get("Content-Type", "")):
                lines = r.text.strip().split("\n")
                test_pass(f"CSV Export: {export_type}",
                         f"{len(lines)-1} rows exported")
            else:
                test_fail(f"CSV Export: {export_type}",
                         f"Status {r.status_code}")
        except Exception as e:
            test_fail(f"CSV Export: {export_type}", str(e))

# ══════════════════════════════════════════════════════════════
# TEST SECTION 12: LOGOUT
# ══════════════════════════════════════════════════════════════
def test_logout():
    print_section("12. Logout & Session Cleanup")

    s = get_session("admin", "admin123")
    if not s:
        test_fail("Session creation failed")
        return

    # Test: Logout
    try:
        r = s.post(f"{BASE_URL}/api/logout", timeout=TIMEOUT)
        d = r.json()
        if d.get("success"):
            test_pass("Logout successful")
        else:
            test_fail("Logout", d.get("error", ""))
    except Exception as e:
        test_fail("Logout", str(e))

    # Test: After logout, protected route returns 401
    try:
        r = s.get(f"{BASE_URL}/api/customers", timeout=TIMEOUT)
        if r.status_code == 401:
            test_pass("After logout, session is invalidated", "401 on protected route")
        else:
            test_fail("Session should be invalid after logout",
                     f"Got {r.status_code}")
    except Exception as e:
        test_fail("Post-logout session check", str(e))

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
def print_summary():
    total = passed + failed + warnings
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}  QUALITY ASSURANCE REPORT — TechZone ERP{RESET}")
    print(f"{BOLD}{'='*60}{RESET}")
    print(f"  Total Tests  : {BOLD}{total}{RESET}")
    print(f"  {GREEN}✅ Passed   : {passed}{RESET}")
    print(f"  {RED}❌ Failed   : {failed}{RESET}")
    print(f"  {YELLOW}⚠️  Warnings : {warnings}{RESET}")
    print(f"{BOLD}{'='*60}{RESET}")

    if failed == 0:
        print(f"\n  {GREEN}{BOLD}🎉 ALL TESTS PASSED! System is working correctly.{RESET}")
    elif failed <= 3:
        print(f"\n  {YELLOW}{BOLD}⚠️  Minor issues found. Check failed tests above.{RESET}")
    else:
        print(f"\n  {RED}{BOLD}❌ Multiple failures. Review the errors above.{RESET}")

    score = round((passed / total) * 100) if total > 0 else 0
    bar_filled = int(score / 5)
    bar = "█" * bar_filled + "░" * (20 - bar_filled)
    color = GREEN if score >= 90 else YELLOW if score >= 70 else RED
    print(f"\n  QA Score: {color}{BOLD}{score}%{RESET}  [{color}{bar}{RESET}]")
    print(f"\n  {CYAN}TechZone ERP · CS2013 · FAST NUCES Karachi{RESET}\n")

# ══════════════════════════════════════════════════════════════
# MAIN — RUN ALL TESTS
# ══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print_header("TechZone ERP — QA Test Suite v2.0")
    print(f"  {CYAN}Target: {BASE_URL}{RESET}")
    print(f"  {CYAN}Time  : {time.strftime('%d %b %Y %H:%M:%S')}{RESET}")

    # Run all test sections
    test_connectivity()
    test_authentication()
    test_rbac()
    test_customers()
    test_products()
    test_orders()
    test_suppliers()
    test_innovations()
    test_reports()
    test_dashboard()
    test_exports()
    test_logout()

    # Final summary
    print_summary()
