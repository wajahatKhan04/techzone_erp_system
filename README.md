# ⚡ TechZone ERP System
### Mini ERP — CS2013 | FAST NUCES Karachi | BS FinTech | Spring 2026

---

## 👥 Team Members
| Name | Student ID |
|------|-----------|
| Muhammad Wajahat Khan | 24K-5554 |
| Muhammad Haider Hasnain | 24K-5589 |

**Instructor:** Ms. Magdalene Gloria Miranda
**Course:** CS2013 — Introduction to Database Systems

---

## 📁 Project Structure
```
TechZone-ERP/
├── app.py                        ← Flask Backend (all API routes)
├── database.py                   ← PostgreSQL connection (SSL for Neon)
├── requirements.txt              ← Python packages
├── render.yaml                   ← Render deployment config
├── test_techzone.py              ← QA automated tests (60 tests)
├── .env.example                  ← Environment config template
├── .gitignore                    ← Git ignore rules
├── README.md                     ← This file
├── templates/
│   ├── index.html                ← Main ERP Frontend
│   └── login.html                ← Login Page
├── static/
│   ├── css/                      ← Stylesheets
│   └── js/                       ← JavaScript
└── database/
    ├── techzone_erp_complete.sql ← Full database script
    └── fix_database.sql          ← Fix script for new tables
```

---

## ⚡ Features

### Core ERP Modules
- 📊 **Dashboard** — KPIs, revenue charts, period filter (7/30/90/365 days)
- 👥 **Customers** — Full CRUD with validation + CSV export
- 📦 **Products** — Inventory with stock status + CSV export
- 📋 **Orders** — Order tracking with line items + status updates
- 🏭 **Suppliers** — Supplier directory + supply value
- 💳 **Transactions** — Payment history + method breakdown

### Innovation Features
- 🤖 **AI Reorder Suggestions** — Claude AI analyzes sales + predicts restocking
- 📈 **Profit Margin Calculator** — Supply cost vs sale price per product
- 📦 **Stock Movements** — Complete IN/OUT history log
- 📋 **Purchase Orders** — Full procurement workflow
- 📊 **Reports** — 6 SQL views on frontend
- 🔍 **Audit Log** — Complete trail of all changes

### Security
- 🔐 Session-based authentication
- 👑 Role-based access (Admin/Sales/Inventory) — Flask + PostgreSQL DCL
- 🔒 bcrypt password hashing
- ✅ Input validation (frontend + backend)
- 🛡️ Safe delete with referential integrity checks

---

## 🛠️ Local Setup

```bash
# 1. Install packages
pip install -r requirements.txt

# 2. Create .env file
copy .env.example .env

# 3. Edit .env with your PostgreSQL password

# 4. Run database script in pgAdmin
# database/techzone_erp_complete.sql

# 5. Start app
python app.py

# 6. Open browser
# http://localhost:5000
```

---

## 🚀 Deployment (Render + Neon)

```bash
# 1. Push to GitHub
git init
git add .
git commit -m "TechZone ERP v2.0"
git push origin main

# 2. Render.com → New Web Service → Connect GitHub repo
# Build: pip install -r requirements.txt
# Start: gunicorn app:app

# 3. Add environment variables in Render dashboard
```

---

## 👤 Login Credentials
| Role | Username | Password | Access |
|------|----------|----------|--------|
| Admin | `admin` | `admin123` | All modules |
| Sales | `sales` | `sales123` | Orders, Customers, Transactions |
| Inventory | `inventory` | `inv123` | Products, Suppliers, Stock |

---

## 🗄️ Database
- **13 Tables** — normalized to 3NF
- **6 Views** — reporting and analytics
- **5 Triggers** — automation
- **3 DCL Roles** — PostgreSQL access control

## 🔬 Quality Assurance
```bash
# Run automated tests (app must be running)
python test_techzone.py
# Expected: 60/60 PASS — QA Score 100%
```

---

## 🏗️ Tech Stack
| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL (Neon Cloud) |
| Backend | Python Flask 3.x + gunicorn |
| AI | Anthropic Claude API |
| Security | bcrypt, Flask sessions |
| Frontend | HTML5, CSS3, Vanilla JS |
| Hosting | Render.com |

---

*TechZone ERP v2.0 · CS2013 · FAST NUCES Karachi · BS FinTech · Spring 2026*
