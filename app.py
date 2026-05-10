from flask import Flask, jsonify, request, render_template, session, redirect, Response
from flask_cors import CORS
from database import execute_query
import os, re, csv, io
from functools import wraps
from dotenv import load_dotenv
import bcrypt

load_dotenv()

app = Flask(__name__)
app.secret_key = 'techzone_erp_secret_2026'
CORS(app, supports_credentials=True)

ROLE_PAGES = {
    'admin':     ['dashboard','customers','products','orders','suppliers','transactions','stock_movements','purchase_orders','reports'],
    'sales':     ['dashboard','customers','products','orders','transactions','reports'],
    'inventory': ['dashboard','products','suppliers','stock_movements','purchase_orders'],
}

def val_email(v):  return bool(re.match(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', v))
def val_phone(v):  return bool(re.match(r'^[\d\s\-\+\(\)]{7,20}$', v))
def val_pos(v):
    try: return float(v) > 0
    except: return False
def val_int(v):
    try: return int(v) >= 0
    except: return False
def val_req(v): return v is not None and str(v).strip() != ''

def login_required(f):
    @wraps(f)
    def dec(*a, **kw):
        if 'user' not in session:
            return jsonify({'success': False, 'error': 'Unauthorized', 'redirect': '/login'}), 401
        return f(*a, **kw)
    return dec

def role_required(*roles):
    def decorator(f):
        @wraps(f)
        def dec(*a, **kw):
            if 'user' not in session:
                return jsonify({'success': False, 'error': 'Unauthorized'}), 401
            if session['user']['role'] not in roles:
                return jsonify({'success': False, 'error': f'Access denied.'}), 403
            return f(*a, **kw)
        return dec
    return decorator

# ── AUDIT LOG HELPER ──────────────────────────────────────────────────────────
def write_audit(table_name, operation, record_id, changed_by, old_values=None, new_values=None):
    """Write to audit_log table. Fails silently so it never breaks main operations."""
    try:
        import json
        execute_query(
            """INSERT INTO mini_erp.audit_log
               (table_name, operation, record_id, changed_by, old_values, new_values)
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (
                table_name, operation, record_id, changed_by,
                json.dumps(old_values) if old_values else None,
                json.dumps(new_values) if new_values else None
            ),
            fetch=False
        )
    except Exception:
        pass  # Audit log failure must never crash the main request

# ── ROUTES ────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    if 'user' not in session: return redirect('/login')
    return render_template('index.html')

@app.route('/login')
def login_page():
    if 'user' in session: return redirect('/')
    return render_template('login.html')

@app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        username = data.get('username','').strip()
        password = data.get('password','').strip()
        if not username or not password:
            return jsonify({'success': False, 'error': 'Username and password required'}), 400

        user = execute_query(
            "SELECT user_id, username, role, full_name, password FROM mini_erp.Users WHERE username=%s",
            (username,)
        )
        if not user:
            return jsonify({'success': False, 'error': 'Invalid username or password'}), 401

        stored_pw = user[0]['password']

        # Support both bcrypt hashes AND plain-text (for existing data during migration)
        if stored_pw.startswith('$2b$') or stored_pw.startswith('$2a$'):
            pw_ok = bcrypt.checkpw(password.encode('utf-8'), stored_pw.encode('utf-8'))
        else:
            pw_ok = (password == stored_pw)  # plain-text fallback

        if not pw_ok:
            return jsonify({'success': False, 'error': 'Invalid username or password'}), 401

        session['user'] = {
            'user_id':   user[0]['user_id'],
            'username':  user[0]['username'],
            'role':      user[0]['role'],
            'full_name': user[0]['full_name']
        }
        write_audit('Users', 'LOGIN', user[0]['user_id'], username)
        return jsonify({
            'success':   True,
            'message':   f'Welcome back, {user[0]["full_name"]}!',
            'role':      user[0]['role'],
            'full_name': user[0]['full_name'],
            'pages':     ROLE_PAGES[user[0]['role']]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/logout', methods=['POST'])
def logout():
    if 'user' in session:
        write_audit('Users', 'LOGOUT', session['user'].get('user_id'), session['user'].get('username'))
    session.clear()
    return jsonify({'success': True})

@app.route('/api/me', methods=['GET'])
@login_required
def get_me():
    u = session['user']
    return jsonify({'success': True, 'user': u, 'pages': ROLE_PAGES[u['role']]})

@app.route('/api/dashboard', methods=['GET'])
@login_required
def get_dashboard():
    try:
        period = request.args.get('period', '30')
        try: period = int(period)
        except: period = 30

        s = {}
        s['total_revenue'] = float(execute_query("SELECT COALESCE(SUM(amount),0) AS r FROM mini_erp.Transaction")[0]['r'])

        # Period-filtered revenue (NEW)
        s['period_revenue'] = float(execute_query(
            """SELECT COALESCE(SUM(t.amount),0) AS r
               FROM mini_erp.Transaction t
               JOIN mini_erp.Orders o ON t.order_id=o.order_id
               WHERE o.order_date >= CURRENT_DATE - INTERVAL '%s days'
               AND o.order_status='Completed'""",
            (period,)
        )[0]['r'])
        s['period_days'] = period

        o = execute_query("SELECT COUNT(*) AS t, COUNT(CASE WHEN order_status='Completed' THEN 1 END) AS c, COUNT(CASE WHEN order_status='Pending' THEN 1 END) AS p FROM mini_erp.Orders")[0]
        s['orders'] = {'total': o['t'], 'completed': o['c'], 'pending': o['p']}
        s['active_customers'] = execute_query("SELECT COUNT(*) AS n FROM mini_erp.Customer WHERE customer_status='Active'")[0]['n']
        s['low_stock'] = execute_query("SELECT COUNT(*) AS n FROM mini_erp.Product WHERE stock_quantity < 20")[0]['n']
        s['active_suppliers'] = execute_query("SELECT COUNT(*) AS n FROM mini_erp.Supplier WHERE supplier_status='Active'")[0]['n']
        s['monthly_revenue'] = execute_query(
            "SELECT TO_CHAR(o.order_date,'Mon') AS month, EXTRACT(MONTH FROM o.order_date) AS month_num, COALESCE(SUM(t.amount),0) AS revenue FROM mini_erp.Orders o LEFT JOIN mini_erp.Transaction t ON o.order_id=t.order_id WHERE o.order_status='Completed' GROUP BY TO_CHAR(o.order_date,'Mon'),EXTRACT(MONTH FROM o.order_date) ORDER BY month_num"
        )
        s['top_products'] = execute_query(
            "SELECT p.name, SUM(od.quantity) AS units_sold, SUM(od.quantity*od.price) AS revenue FROM mini_erp.Order_Details od JOIN mini_erp.Product p ON od.product_id=p.product_id JOIN mini_erp.Orders o ON od.order_id=o.order_id WHERE o.order_status='Completed' GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 5"
        )
        s['recent_orders'] = execute_query(
            "SELECT o.order_id, c.name AS customer, o.total_amount, o.order_status, TO_CHAR(o.order_date,'DD Mon YYYY') AS order_date FROM mini_erp.Orders o JOIN mini_erp.Customer c ON o.customer_id=c.customer_id ORDER BY o.order_date DESC LIMIT 5"
        )

        # Payment balance overview (NEW - uses view_payment_status)
        try:
            s['pending_payments'] = execute_query(
                "SELECT COUNT(*) AS n, COALESCE(SUM(balance_due),0) AS total FROM mini_erp.view_payment_status WHERE balance_due > 0"
            )[0]
        except Exception:
            s['pending_payments'] = {'n': 0, 'total': 0}

        return jsonify({'success': True, 'data': s})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@login_required
def get_notifications():
    try:
        notifs = []
        low = execute_query(
            "SELECT product_id, name, stock_quantity, CASE WHEN stock_quantity=0 THEN 'Out of Stock' WHEN stock_quantity<10 THEN 'Critical' ELSE 'Low Stock' END AS status FROM mini_erp.Product WHERE stock_quantity < 20 ORDER BY stock_quantity ASC LIMIT 10"
        )
        for p in low:
            notifs.append({'type':'stock','level':'danger' if p['stock_quantity']<10 else 'warning','message':f"{p['name']} — {p['status']} ({p['stock_quantity']} units)",'product_id':p['product_id']})
        pending = execute_query(
            "SELECT o.order_id, c.name AS customer, TO_CHAR(o.order_date,'DD Mon') AS date FROM mini_erp.Orders o JOIN mini_erp.Customer c ON o.customer_id=c.customer_id WHERE o.order_status='Pending' ORDER BY o.order_date ASC LIMIT 5"
        )
        for o in pending:
            notifs.append({'type':'order','level':'info','message':f"Pending Order #{o['order_id']} — {o['customer']} ({o['date']})",'order_id':o['order_id']})

        # Pending purchase orders notification (NEW)
        try:
            po_pending = execute_query("SELECT COUNT(*) AS n FROM mini_erp.Purchase_Order WHERE po_status='Pending'")[0]['n']
            if po_pending > 0:
                notifs.append({'type':'po','level':'info','message':f"{po_pending} Purchase Order(s) pending approval"})
        except Exception:
            pass

        return jsonify({'success': True, 'data': notifs, 'count': len(notifs)})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── CUSTOMERS ─────────────────────────────────────────────────────────────────

@app.route('/api/customers', methods=['GET'])
@login_required
def get_customers():
    try:
        data = execute_query(
            "SELECT c.customer_id,c.name,c.phone,c.email,c.address,c.customer_status,TO_CHAR(c.join_date,'DD Mon YYYY') AS join_date,COUNT(o.order_id) AS total_orders,COALESCE(SUM(o.total_amount),0) AS total_spent FROM mini_erp.Customer c LEFT JOIN mini_erp.Orders o ON c.customer_id=o.customer_id GROUP BY c.customer_id,c.name,c.phone,c.email,c.address,c.customer_status,c.join_date ORDER BY c.customer_id"
        )
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers', methods=['POST'])
@login_required
@role_required('admin','sales')
def add_customer():
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Client name is required.')
        if d.get('email') and not val_email(d['email']): errs.append('Invalid email format.')
        if d.get('phone') and not val_phone(d['phone']): errs.append('Phone: only digits/dashes/spaces.')
        if d.get('customer_status') not in ['Active','Inactive','Blocked']: errs.append('Invalid status.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        execute_query(
            "INSERT INTO mini_erp.Customer(name,phone,email,address,customer_status) VALUES(%s,%s,%s,%s,%s)",
            (d['name'].strip(), d.get('phone','').strip() or None, d.get('email','').strip() or None,
             d.get('address','').strip() or None, d.get('customer_status','Active')),
            fetch=False
        )
        new_id = execute_query("SELECT MAX(customer_id) AS id FROM mini_erp.Customer")[0]['id']
        write_audit('Customer', 'INSERT', new_id, session['user']['username'], new_values=d)
        return jsonify({'success': True, 'message': 'Client added successfully'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers/<int:id>', methods=['PUT'])
@login_required
@role_required('admin','sales')
def update_customer(id):
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Client name is required.')
        if d.get('email') and not val_email(d['email']): errs.append('Invalid email format.')
        if d.get('phone') and not val_phone(d['phone']): errs.append('Phone: only digits/dashes/spaces.')
        if d.get('customer_status') not in ['Active','Inactive','Blocked']: errs.append('Invalid status.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        old = execute_query("SELECT * FROM mini_erp.Customer WHERE customer_id=%s", (id,))
        execute_query(
            "UPDATE mini_erp.Customer SET name=%s,phone=%s,email=%s,address=%s,customer_status=%s WHERE customer_id=%s",
            (d['name'].strip(), d.get('phone','').strip() or None, d.get('email','').strip() or None,
             d.get('address','').strip() or None, d['customer_status'], id),
            fetch=False
        )
        write_audit('Customer', 'UPDATE', id, session['user']['username'],
                    old_values=old[0] if old else None, new_values=d)
        return jsonify({'success': True, 'message': 'Client updated successfully'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers/<int:id>', methods=['DELETE'])
@login_required
@role_required('admin')
def delete_customer(id):
    try:
        cnt = execute_query("SELECT COUNT(*) AS c FROM mini_erp.Orders WHERE customer_id=%s", (id,))[0]['c']
        if cnt > 0: return jsonify({'success': False, 'error': f'Cannot delete — client has {cnt} order(s).'}), 400
        old = execute_query("SELECT * FROM mini_erp.Customer WHERE customer_id=%s", (id,))
        execute_query("DELETE FROM mini_erp.Customer WHERE customer_id=%s", (id,), fetch=False)
        write_audit('Customer', 'DELETE', id, session['user']['username'], old_values=old[0] if old else None)
        return jsonify({'success': True, 'message': 'Client deleted'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── PRODUCTS ──────────────────────────────────────────────────────────────────

@app.route('/api/products', methods=['GET'])
@login_required
def get_products():
    try:
        data = execute_query(
            "SELECT p.product_id,p.name,p.price,p.stock_quantity,c.category_name,c.category_id,CASE WHEN p.stock_quantity=0 THEN 'Out of Stock' WHEN p.stock_quantity<10 THEN 'Critical' WHEN p.stock_quantity<20 THEN 'Low Stock' ELSE 'In Stock' END AS stock_status FROM mini_erp.Product p JOIN mini_erp.Category c ON p.category_id=c.category_id ORDER BY p.product_id"
        )
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products', methods=['POST'])
@login_required
@role_required('admin','inventory')
def add_product():
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Product name required.')
        if not val_pos(d.get('price')): errs.append('Price must be positive.')
        if not val_int(d.get('stock_quantity')): errs.append('Stock must be 0 or more.')
        if not val_req(d.get('category_id')): errs.append('Category required.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        execute_query(
            "INSERT INTO mini_erp.Product(name,price,stock_quantity,category_id) VALUES(%s,%s,%s,%s)",
            (d['name'].strip(), float(d['price']), int(d['stock_quantity']), int(d['category_id'])),
            fetch=False
        )
        new_id = execute_query("SELECT MAX(product_id) AS id FROM mini_erp.Product")[0]['id']
        write_audit('Product', 'INSERT', new_id, session['user']['username'], new_values=d)
        return jsonify({'success': True, 'message': 'Product added'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products/<int:id>', methods=['PUT'])
@login_required
@role_required('admin','inventory')
def update_product(id):
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Product name required.')
        if not val_pos(d.get('price')): errs.append('Price must be positive.')
        if not val_int(d.get('stock_quantity')): errs.append('Stock must be 0 or more.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        old = execute_query("SELECT * FROM mini_erp.Product WHERE product_id=%s", (id,))
        execute_query(
            "UPDATE mini_erp.Product SET name=%s,price=%s,stock_quantity=%s,category_id=%s WHERE product_id=%s",
            (d['name'].strip(), float(d['price']), int(d['stock_quantity']), int(d['category_id']), id),
            fetch=False
        )
        write_audit('Product', 'UPDATE', id, session['user']['username'],
                    old_values=old[0] if old else None, new_values=d)
        return jsonify({'success': True, 'message': 'Product updated'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/products/<int:id>', methods=['DELETE'])
@login_required
@role_required('admin','inventory')
def delete_product(id):
    try:
        cnt = execute_query("SELECT COUNT(*) AS c FROM mini_erp.Order_Details WHERE product_id=%s", (id,))[0]['c']
        if cnt > 0: return jsonify({'success': False, 'error': f'Cannot delete — in {cnt} order(s).'}), 400
        old = execute_query("SELECT * FROM mini_erp.Product WHERE product_id=%s", (id,))
        execute_query("DELETE FROM mini_erp.Product WHERE product_id=%s", (id,), fetch=False)
        write_audit('Product', 'DELETE', id, session['user']['username'], old_values=old[0] if old else None)
        return jsonify({'success': True, 'message': 'Product deleted'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── ORDERS ────────────────────────────────────────────────────────────────────

@app.route('/api/orders', methods=['GET'])
@login_required
@role_required('admin','sales')
def get_orders():
    try:
        data = execute_query(
            "SELECT o.order_id,c.name AS customer_name,e.name AS employee_name,TO_CHAR(o.order_date,'DD Mon YYYY HH24:MI') AS order_date,o.total_amount,o.order_status,t.payment_method,t.amount AS paid_amount FROM mini_erp.Orders o JOIN mini_erp.Customer c ON o.customer_id=c.customer_id LEFT JOIN mini_erp.Employee e ON o.employee_id=e.employee_id LEFT JOIN mini_erp.Transaction t ON o.order_id=t.order_id ORDER BY o.order_id DESC"
        )
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/orders/<int:id>', methods=['GET'])
@login_required
@role_required('admin','sales')
def get_order_details(id):
    try:
        data = execute_query(
            "SELECT p.name AS product_name,od.quantity,od.price,(od.quantity*od.price) AS line_total FROM mini_erp.Order_Details od JOIN mini_erp.Product p ON od.product_id=p.product_id WHERE od.order_id=%s",
            (id,)
        )
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/orders/<int:id>/status', methods=['PUT'])
@login_required
@role_required('admin','sales')
def update_order_status(id):
    try:
        d = request.get_json()
        if d.get('status') not in ['Completed','Cancelled','Pending']:
            return jsonify({'success': False, 'error': 'Invalid status'}), 400
        old = execute_query("SELECT order_status FROM mini_erp.Orders WHERE order_id=%s", (id,))
        execute_query("UPDATE mini_erp.Orders SET order_status=%s WHERE order_id=%s", (d['status'], id), fetch=False)
        write_audit('Orders', 'UPDATE', id, session['user']['username'],
                    old_values={'order_status': old[0]['order_status'] if old else None},
                    new_values={'order_status': d['status']})
        return jsonify({'success': True, 'message': 'Order status updated'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── SUPPLIERS ─────────────────────────────────────────────────────────────────

@app.route('/api/suppliers', methods=['GET'])
@login_required
@role_required('admin','inventory')
def get_suppliers():
    try:
        data = execute_query(
            "SELECT s.supplier_id,s.name,s.contact,s.city,s.supplier_status,TO_CHAR(s.join_date,'DD Mon YYYY') AS join_date,COUNT(sp.product_id) AS products_supplied,COALESCE(SUM(sp.quantity*sp.supply_price),0) AS total_supply_value FROM mini_erp.Supplier s LEFT JOIN mini_erp.Supplier_Product sp ON s.supplier_id=sp.supplier_id GROUP BY s.supplier_id,s.name,s.contact,s.city,s.supplier_status,s.join_date ORDER BY s.supplier_id"
        )
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/suppliers', methods=['POST'])
@login_required
@role_required('admin','inventory')
def add_supplier():
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Supplier name required.')
        if d.get('contact') and not val_phone(d['contact']): errs.append('Contact: only digits/dashes/spaces.')
        if d.get('supplier_status') not in ['Active','Inactive']: errs.append('Invalid status.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        execute_query(
            "INSERT INTO mini_erp.Supplier(name,contact,city,supplier_status) VALUES(%s,%s,%s,%s)",
            (d['name'].strip(), d.get('contact','').strip() or None,
             d.get('city','').strip() or None, d.get('supplier_status','Active')),
            fetch=False
        )
        new_id = execute_query("SELECT MAX(supplier_id) AS id FROM mini_erp.Supplier")[0]['id']
        write_audit('Supplier', 'INSERT', new_id, session['user']['username'], new_values=d)
        return jsonify({'success': True, 'message': 'Supplier added'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/suppliers/<int:id>', methods=['PUT'])
@login_required
@role_required('admin','inventory')
def update_supplier(id):
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('name')): errs.append('Supplier name required.')
        if d.get('contact') and not val_phone(d['contact']): errs.append('Contact: only digits/dashes/spaces.')
        if d.get('supplier_status') not in ['Active','Inactive']: errs.append('Invalid status.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        old = execute_query("SELECT * FROM mini_erp.Supplier WHERE supplier_id=%s", (id,))
        execute_query(
            "UPDATE mini_erp.Supplier SET name=%s,contact=%s,city=%s,supplier_status=%s WHERE supplier_id=%s",
            (d['name'].strip(), d.get('contact','').strip() or None,
             d.get('city','').strip() or None, d['supplier_status'], id),
            fetch=False
        )
        write_audit('Supplier', 'UPDATE', id, session['user']['username'],
                    old_values=old[0] if old else None, new_values=d)
        return jsonify({'success': True, 'message': 'Supplier updated'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/suppliers/<int:id>', methods=['DELETE'])
@login_required
@role_required('admin')
def delete_supplier(id):
    try:
        cnt = execute_query("SELECT COUNT(*) AS c FROM mini_erp.Supplier_Product WHERE supplier_id=%s", (id,))[0]['c']
        if cnt > 0: return jsonify({'success': False, 'error': f'Cannot delete — has {cnt} supply record(s).'}), 400
        old = execute_query("SELECT * FROM mini_erp.Supplier WHERE supplier_id=%s", (id,))
        execute_query("DELETE FROM mini_erp.Supplier WHERE supplier_id=%s", (id,), fetch=False)
        write_audit('Supplier', 'DELETE', id, session['user']['username'], old_values=old[0] if old else None)
        return jsonify({'success': True, 'message': 'Supplier deleted'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── TRANSACTIONS ──────────────────────────────────────────────────────────────

@app.route('/api/transactions', methods=['GET'])
@login_required
@role_required('admin','sales')
def get_transactions():
    try:
        # Check if payment_status column exists — handle both old and new schema
        col_check = execute_query("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema='mini_erp' AND table_name='transaction'
              AND column_name='payment_status'
        """)
        has_payment_status = len(col_check) > 0

        if has_payment_status:
            query = """SELECT t.transaction_id, c.name AS customer_name, o.order_id,
                              t.amount, t.payment_method, t.payment_status,
                              TO_CHAR(t.transaction_date,'DD Mon YYYY') AS transaction_date,
                              o.order_status
                       FROM mini_erp.Transaction t
                       JOIN mini_erp.Orders o  ON t.order_id    = o.order_id
                       JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
                       ORDER BY t.transaction_id DESC"""
        else:
            query = """SELECT t.transaction_id, c.name AS customer_name, o.order_id,
                              t.amount, t.payment_method,
                              'Paid' AS payment_status,
                              TO_CHAR(t.transaction_date,'DD Mon YYYY') AS transaction_date,
                              o.order_status
                       FROM mini_erp.Transaction t
                       JOIN mini_erp.Orders o  ON t.order_id    = o.order_id
                       JOIN mini_erp.Customer c ON o.customer_id = c.customer_id
                       ORDER BY t.transaction_id DESC"""

        data = execute_query(query)
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── STOCK MOVEMENTS (NEW — uses Stock_Transaction table) ─────────────────────

@app.route('/api/stock-movements', methods=['GET'])
@login_required
@role_required('admin','inventory')
def get_stock_movements():
    try:
        # Check which columns exist in Stock_Transaction
        cols = execute_query("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema='mini_erp' AND table_name='stock_transaction'
        """)
        col_names = [c['column_name'] for c in cols]

        # Build query based on available columns
        type_col  = 'st.transaction_type' if 'transaction_type' in col_names else "'OUT' AS transaction_type"
        date_col  = 'TO_CHAR(st.transaction_date,\'DD Mon YYYY HH24:MI\') AS txn_date' if 'transaction_date' in col_names else 'NULL AS txn_date'
        id_col    = 'st.stock_txn_id' if 'stock_txn_id' in col_names else 'st.id AS stock_txn_id'

        data = execute_query(f"""
            SELECT {id_col},
                   p.name AS product_name,
                   p.product_id,
                   {type_col},
                   st.quantity,
                   {date_col},
                   p.stock_quantity AS current_stock
            FROM mini_erp.Stock_Transaction st
            JOIN mini_erp.Product p ON st.product_id = p.product_id
            ORDER BY {id_col} DESC
            LIMIT 100
        """)
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── PURCHASE ORDERS (NEW) ─────────────────────────────────────────────────────

@app.route('/api/purchase-orders', methods=['GET'])
@login_required
@role_required('admin','inventory')
def get_purchase_orders():
    try:
        # Check if table exists
        tbl = execute_query("""
            SELECT 1 FROM information_schema.tables
            WHERE table_schema='mini_erp' AND table_name='purchase_order'
        """)
        if not tbl:
            return jsonify({
                'success': False,
                'error': 'Purchase_Order table not found. Run database/fix_database.sql in pgAdmin.'
            }), 500

        data = execute_query("""
            SELECT po.po_id, s.name AS supplier_name, p.name AS product_name,
                   po.quantity, po.unit_cost,
                   (po.quantity * po.unit_cost) AS total_cost,
                   po.po_status,
                   TO_CHAR(po.created_at,'DD Mon YYYY') AS created_date
            FROM mini_erp.Purchase_Order po
            JOIN mini_erp.Supplier s ON po.supplier_id = s.supplier_id
            JOIN mini_erp.Product  p ON po.product_id  = p.product_id
            ORDER BY po.po_id DESC
        """)
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/purchase-orders', methods=['POST'])
@login_required
@role_required('admin','inventory')
def add_purchase_order():
    try:
        d = request.get_json()
        errs = []
        if not val_req(d.get('supplier_id')): errs.append('Supplier required.')
        if not val_req(d.get('product_id')): errs.append('Product required.')
        if not val_pos(d.get('quantity')): errs.append('Quantity must be positive.')
        if not val_pos(d.get('unit_cost')): errs.append('Unit cost must be positive.')
        if errs: return jsonify({'success': False, 'error': ' | '.join(errs)}), 400
        execute_query(
            """INSERT INTO mini_erp.Purchase_Order(supplier_id, product_id, quantity, unit_cost, po_status)
               VALUES(%s,%s,%s,%s,'Pending')""",
            (int(d['supplier_id']), int(d['product_id']), int(d['quantity']), float(d['unit_cost'])),
            fetch=False
        )
        new_id = execute_query("SELECT MAX(po_id) AS id FROM mini_erp.Purchase_Order")[0]['id']
        write_audit('Purchase_Order', 'INSERT', new_id, session['user']['username'], new_values=d)
        return jsonify({'success': True, 'message': 'Purchase order created'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/purchase-orders/<int:id>/receive', methods=['PUT'])
@login_required
@role_required('admin','inventory')
def receive_purchase_order(id):
    """Mark PO as Received → triggers stock increase automatically via DB trigger."""
    try:
        po = execute_query("SELECT * FROM mini_erp.Purchase_Order WHERE po_id=%s", (id,))
        if not po: return jsonify({'success': False, 'error': 'Purchase order not found'}), 404
        if po[0]['po_status'] == 'Received':
            return jsonify({'success': False, 'error': 'Already received'}), 400

        execute_query(
            "UPDATE mini_erp.Purchase_Order SET po_status='Received' WHERE po_id=%s", (id,), fetch=False
        )
        # Manually increase stock (if no DB trigger for PO receive)
        execute_query(
            "UPDATE mini_erp.Product SET stock_quantity = stock_quantity + %s WHERE product_id=%s",
            (po[0]['quantity'], po[0]['product_id']), fetch=False
        )
        # Log stock movement
        execute_query(
            "INSERT INTO mini_erp.Stock_Transaction(product_id, transaction_type, quantity) VALUES(%s,'IN',%s)",
            (po[0]['product_id'], po[0]['quantity']), fetch=False
        )
        write_audit('Purchase_Order', 'UPDATE', id, session['user']['username'],
                    old_values={'po_status':'Pending'}, new_values={'po_status':'Received'})
        return jsonify({'success': True, 'message': 'Purchase order received — stock updated'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/purchase-orders/<int:id>/cancel', methods=['PUT'])
@login_required
@role_required('admin','inventory')
def cancel_purchase_order(id):
    try:
        po = execute_query("SELECT po_status FROM mini_erp.Purchase_Order WHERE po_id=%s", (id,))
        if not po: return jsonify({'success': False, 'error': 'Not found'}), 404
        if po[0]['po_status'] != 'Pending':
            return jsonify({'success': False, 'error': 'Only Pending orders can be cancelled'}), 400
        execute_query(
            "UPDATE mini_erp.Purchase_Order SET po_status='Cancelled' WHERE po_id=%s", (id,), fetch=False
        )
        write_audit('Purchase_Order', 'UPDATE', id, session['user']['username'],
                    old_values={'po_status':'Pending'}, new_values={'po_status':'Cancelled'})
        return jsonify({'success': True, 'message': 'Purchase order cancelled'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── REPORTS (NEW — uses existing views) ──────────────────────────────────────

@app.route('/api/reports/sales', methods=['GET'])
@login_required
@role_required('admin','sales')
def report_sales():
    try:
        data = execute_query("SELECT * FROM mini_erp.view_sales_report ORDER BY 1 DESC LIMIT 100")
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/reports/inventory', methods=['GET'])
@login_required
def report_inventory():
    try:
        data = execute_query("SELECT * FROM mini_erp.view_inventory_status ORDER BY stock_quantity ASC")
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/reports/customers', methods=['GET'])
@login_required
@role_required('admin','sales')
def report_customers():
    try:
        data = execute_query("SELECT * FROM mini_erp.view_customer_purchase_history ORDER BY 1 LIMIT 100")
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/reports/transactions', methods=['GET'])
@login_required
@role_required('admin','sales')
def report_transactions():
    try:
        data = execute_query("SELECT * FROM mini_erp.view_transaction_summary ORDER BY 1 DESC LIMIT 100")
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/reports/suppliers', methods=['GET'])
@login_required
@role_required('admin','inventory')
def report_suppliers():
    try:
        data = execute_query("SELECT * FROM mini_erp.view_supplier_supply_records ORDER BY 1")
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── AUDIT LOG (NEW — admin only) ──────────────────────────────────────────────

@app.route('/api/audit-log', methods=['GET'])
@login_required
@role_required('admin')
def get_audit_log():
    try:
        # Check if audit_log table exists
        tbl = execute_query("""
            SELECT 1 FROM information_schema.tables
            WHERE table_schema='mini_erp' AND table_name='audit_log'
        """)
        if not tbl:
            return jsonify({
                'success': False,
                'error': 'audit_log table not found. Please run database/fix_database.sql in pgAdmin.'
            }), 500

        data = execute_query("""
            SELECT log_id, table_name, operation, record_id, changed_by,
                   old_values, new_values,
                   TO_CHAR(changed_at,'DD Mon YYYY HH24:MI:SS') AS changed_at
            FROM mini_erp.audit_log
            ORDER BY log_id DESC LIMIT 200
        """)
        return jsonify({'success': True, 'data': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── CATEGORIES & EMPLOYEES ────────────────────────────────────────────────────

@app.route('/api/categories', methods=['GET'])
@login_required
def get_categories():
    try:
        return jsonify({'success': True, 'data': execute_query("SELECT * FROM mini_erp.Category ORDER BY category_id")})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/employees', methods=['GET'])
@login_required
def get_employees():
    try:
        return jsonify({'success': True, 'data': execute_query("SELECT * FROM mini_erp.Employee ORDER BY employee_id")})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── CSV EXPORTS ───────────────────────────────────────────────────────────────

@app.route('/api/export/customers', methods=['GET'])
@login_required
def export_customers():
    try:
        data = execute_query("SELECT c.customer_id,c.name,c.phone,c.email,c.address,c.customer_status,TO_CHAR(c.join_date,'DD Mon YYYY') AS join_date,COUNT(o.order_id) AS total_orders,COALESCE(SUM(o.total_amount),0) AS total_spent FROM mini_erp.Customer c LEFT JOIN mini_erp.Orders o ON c.customer_id=o.customer_id GROUP BY c.customer_id,c.name,c.phone,c.email,c.address,c.customer_status,c.join_date ORDER BY c.customer_id")
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['ID','Name','Phone','Email','Address','Status','Join Date','Total Orders','Total Spent (PKR)'])
        for r in data:
            w.writerow([r['customer_id'],r['name'],r['phone'] or '',r['email'] or '',r['address'] or '',r['customer_status'],r['join_date'],r['total_orders'],r['total_spent']])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_customers.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/export/products', methods=['GET'])
@login_required
def export_products():
    try:
        data = execute_query("SELECT p.product_id,p.name,c.category_name,p.price,p.stock_quantity,CASE WHEN p.stock_quantity=0 THEN 'Out of Stock' WHEN p.stock_quantity<10 THEN 'Critical' WHEN p.stock_quantity<20 THEN 'Low Stock' ELSE 'In Stock' END AS stock_status FROM mini_erp.Product p JOIN mini_erp.Category c ON p.category_id=c.category_id ORDER BY p.product_id")
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['ID','Product Name','Category','Price (PKR)','Stock Qty','Stock Status'])
        for r in data:
            w.writerow([r['product_id'],r['name'],r['category_name'],r['price'],r['stock_quantity'],r['stock_status']])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_products.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/export/orders', methods=['GET'])
@login_required
def export_orders():
    try:
        data = execute_query("SELECT o.order_id,c.name AS customer,e.name AS employee,TO_CHAR(o.order_date,'DD Mon YYYY HH24:MI') AS order_date,o.total_amount,o.order_status,t.payment_method FROM mini_erp.Orders o JOIN mini_erp.Customer c ON o.customer_id=c.customer_id LEFT JOIN mini_erp.Employee e ON o.employee_id=e.employee_id LEFT JOIN mini_erp.Transaction t ON o.order_id=t.order_id ORDER BY o.order_id DESC")
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['Order ID','Customer','Handled By','Date','Amount (PKR)','Status','Payment Method'])
        for r in data:
            w.writerow([r['order_id'],r['customer'],r['employee'] or '',r['order_date'],r['total_amount'],r['order_status'],r['payment_method'] or ''])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_orders.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/export/transactions', methods=['GET'])
@login_required
def export_transactions():
    try:
        data = execute_query("SELECT t.transaction_id,c.name AS customer,o.order_id,t.amount,t.payment_method,TO_CHAR(t.transaction_date,'DD Mon YYYY') AS date,o.order_status FROM mini_erp.Transaction t JOIN mini_erp.Orders o ON t.order_id=o.order_id JOIN mini_erp.Customer c ON o.customer_id=c.customer_id ORDER BY t.transaction_id DESC")
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['TXN ID','Customer','Order ID','Amount (PKR)','Payment Method','Date','Order Status'])
        for r in data:
            w.writerow([r['transaction_id'],r['customer'],r['order_id'],r['amount'],r['payment_method'],r['date'],r['order_status']])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_transactions.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/export/suppliers', methods=['GET'])
@login_required
def export_suppliers():
    try:
        data = execute_query("SELECT s.supplier_id,s.name,s.contact,s.city,s.supplier_status,COUNT(sp.product_id) AS products_supplied,COALESCE(SUM(sp.quantity*sp.supply_price),0) AS total_supply_value FROM mini_erp.Supplier s LEFT JOIN mini_erp.Supplier_Product sp ON s.supplier_id=sp.supplier_id GROUP BY s.supplier_id,s.name,s.contact,s.city,s.supplier_status ORDER BY s.supplier_id")
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['ID','Supplier Name','Contact','City','Status','Products Supplied','Total Supply Value (PKR)'])
        for r in data:
            w.writerow([r['supplier_id'],r['name'],r['contact'] or '',r['city'] or '',r['supplier_status'],r['products_supplied'],r['total_supply_value']])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_suppliers.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/export/purchase-orders', methods=['GET'])
@login_required
@role_required('admin','inventory')
def export_purchase_orders():
    try:
        data = execute_query(
            """SELECT po.po_id, s.name AS supplier, p.name AS product,
                      po.quantity, po.unit_cost, (po.quantity*po.unit_cost) AS total_cost,
                      po.po_status, TO_CHAR(po.created_at,'DD Mon YYYY') AS created_date
               FROM mini_erp.Purchase_Order po
               JOIN mini_erp.Supplier s ON po.supplier_id=s.supplier_id
               JOIN mini_erp.Product p ON po.product_id=p.product_id
               ORDER BY po.po_id DESC"""
        )
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(['PO ID','Supplier','Product','Quantity','Unit Cost (PKR)','Total Cost (PKR)','Status','Date'])
        for r in data:
            w.writerow([r['po_id'],r['supplier'],r['product'],r['quantity'],r['unit_cost'],r['total_cost'],r['po_status'],r['created_date']])
        out.seek(0)
        return Response(out, mimetype='text/csv', headers={'Content-Disposition':'attachment;filename=techzone_purchase_orders.csv'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ── AI REORDER SUGGESTIONS (INNOVATION #1) ───────────────────────────────────
@app.route('/api/ai/reorder-suggestions', methods=['GET'])
@login_required
@role_required('admin', 'inventory')
def ai_reorder_suggestions():
    try:
        import json, urllib.request

        # Step 1: Pull real data from existing tables
        products_data = execute_query("""
            SELECT
                p.product_id,
                p.name                              AS product_name,
                p.stock_quantity                    AS current_stock,
                p.price                             AS sale_price,
                c.category_name,
                COALESCE(s.supplier_name, 'N/A')   AS supplier_name,
                COALESCE(sales.total_sold_30d, 0)  AS sold_last_30_days,
                COALESCE(sales.total_sold_30d, 0) / 30.0 AS daily_avg_sales
            FROM mini_erp.Product p
            JOIN mini_erp.Category c ON p.category_id = c.category_id
            LEFT JOIN (
                SELECT sp.product_id, MIN(s.name) AS supplier_name
                FROM mini_erp.Supplier_Product sp
                JOIN mini_erp.Supplier s ON sp.supplier_id = s.supplier_id
                WHERE s.supplier_status = 'Active'
                GROUP BY sp.product_id
            ) s ON p.product_id = s.product_id
            LEFT JOIN (
                SELECT od.product_id, SUM(od.quantity) AS total_sold_30d
                FROM mini_erp.Order_Details od
                JOIN mini_erp.Orders o ON od.order_id = o.order_id
                WHERE o.order_status = 'Completed'
                  AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
                GROUP BY od.product_id
            ) sales ON p.product_id = sales.product_id
            ORDER BY p.stock_quantity ASC
        """)

        if not products_data:
            return jsonify({'success': False, 'error': 'No product data found'}), 400

        # Step 2: Build prompt
        lines = []
        for p in products_data:
            daily = float(p['daily_avg_sales'])
            days_left = round(p['current_stock'] / daily) if daily > 0 else 999
            lines.append(
                f"- {p['product_name']} | Stock:{p['current_stock']} | "
                f"Sold30d:{p['sold_last_30_days']} | DailyAvg:{round(daily,1)} | "
                f"DaysLeft:{days_left if days_left<999 else 'NoRecentSales'} | "
                f"Supplier:{p['supplier_name']}"
            )

        prompt = """You are an ERP inventory analyst for TechZone Pvt Ltd, IT equipment supplier Karachi Pakistan.

Analyze this product data and respond ONLY with a JSON array, no other text:

""" + "\n".join(lines) + """

JSON format:
[{"product_name":"exact name","current_stock":0,"days_remaining":0,"urgency":"Critical/Warning/OK","recommended_order_qty":0,"reason":"short reason under 12 words","supplier":"name"}]

Rules: Critical=under 7 days or stock 0, Warning=7-20 days or under 20 units, OK=sufficient. Order qty covers 45 days minimum. Include ALL products."""

        # Step 3: Try Claude API, fallback to rule-based
        api_key = os.getenv('ANTHROPIC_API_KEY', '')

        if api_key:
            payload = json.dumps({
                'model': 'claude-sonnet-4-20250514',
                'max_tokens': 2000,
                'messages': [{'role': 'user', 'content': prompt}]
            }).encode('utf-8')
            req = urllib.request.Request(
                'https://api.anthropic.com/v1/messages',
                data=payload,
                headers={'Content-Type':'application/json','x-api-key':api_key,'anthropic-version':'2023-06-01'},
                method='POST'
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                ai_resp = json.loads(resp.read().decode('utf-8'))
            raw = ai_resp['content'][0]['text'].strip()
            if '```json' in raw: raw = raw.split('```json')[1].split('```')[0].strip()
            elif '```' in raw: raw = raw.split('```')[1].split('```')[0].strip()
            suggestions = json.loads(raw)
            ai_powered = True
        else:
            # Rule-based fallback (no API key needed)
            suggestions = []
            for p in products_data:
                daily = float(p['daily_avg_sales'])
                days_left = round(p['current_stock'] / daily) if daily > 0 else 999
                if p['current_stock'] == 0 or (daily > 0 and days_left < 7):
                    urgency = 'Critical'
                elif p['current_stock'] < 20 or (daily > 0 and days_left < 20):
                    urgency = 'Warning'
                else:
                    urgency = 'OK'
                rec_qty = max(int(daily * 45), 10) if daily > 0 else 20
                suggestions.append({
                    'product_name': p['product_name'],
                    'current_stock': p['current_stock'],
                    'days_remaining': days_left if days_left < 999 else None,
                    'urgency': urgency,
                    'recommended_order_qty': rec_qty,
                    'reason': f"Stock covers {days_left if days_left<999 else 'unknown'} days at current rate",
                    'supplier': p['supplier_name']
                })
            ai_powered = False

        write_audit('AI_Reorder', 'INSERT', None, session['user']['username'],
                    new_values={'products_analyzed': len(products_data), 'ai_powered': ai_powered})
        return jsonify({'success': True, 'data': suggestions, 'ai_powered': ai_powered})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# ── PROFIT MARGIN CALCULATOR (INNOVATION #2) ─────────────────────────────────
@app.route('/api/profit-margins', methods=['GET'])
@login_required
def get_profit_margins():
    try:
        data = execute_query("""
            SELECT
                p.product_id,
                p.name                                                          AS product_name,
                c.category_name,
                p.price                                                         AS sale_price,
                COALESCE(AVG(sp.supply_price), 0)                              AS avg_supply_cost,
                p.price - COALESCE(AVG(sp.supply_price), 0)                    AS profit_per_unit,
                CASE WHEN p.price > 0 THEN
                    ROUND(((p.price - COALESCE(AVG(sp.supply_price),0)) / p.price)*100, 2)
                ELSE 0 END                                                      AS margin_percent,
                COALESCE(SUM(od.quantity), 0)                                  AS total_units_sold,
                COALESCE(SUM(od.quantity),0)*(p.price-COALESCE(AVG(sp.supply_price),0)) AS total_profit_earned,
                p.stock_quantity,
                p.stock_quantity*(p.price-COALESCE(AVG(sp.supply_price),0))    AS stock_profit_value
            FROM mini_erp.Product p
            JOIN mini_erp.Category c ON p.category_id = c.category_id
            LEFT JOIN mini_erp.Supplier_Product sp ON p.product_id = sp.product_id
            LEFT JOIN mini_erp.Order_Details od ON p.product_id = od.product_id
            LEFT JOIN mini_erp.Orders o ON od.order_id = o.order_id AND o.order_status='Completed'
            GROUP BY p.product_id, p.name, c.category_name, p.price, p.stock_quantity
            ORDER BY margin_percent DESC
        """)

        for r in data:
            m = float(r['margin_percent'])
            if m >= 25:   r['health'] = 'Excellent'
            elif m >= 15: r['health'] = 'Good'
            elif m >= 5:  r['health'] = 'Low'
            else:         r['health'] = 'Critical'

        total_rev    = sum(float(r['sale_price'])*float(r['total_units_sold']) for r in data)
        total_cost   = sum(float(r['avg_supply_cost'])*float(r['total_units_sold']) for r in data)
        total_profit = sum(float(r['total_profit_earned']) for r in data)
        ovr_margin   = round((total_profit/total_rev*100),2) if total_rev > 0 else 0

        return jsonify({
            'success': True,
            'data': data,
            'summary': {
                'total_revenue':  round(total_rev, 2),
                'total_cost':     round(total_cost, 2),
                'total_profit':   round(total_profit, 2),
                'overall_margin': ovr_margin,
                'best_product':   max(data, key=lambda x: float(x['margin_percent']))['product_name'] if data else '—',
                'worst_product':  min(data, key=lambda x: float(x['margin_percent']))['product_name'] if data else '—',
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
