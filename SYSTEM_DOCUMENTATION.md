# ViorNet — ISP Management System
## Full System Documentation
**Version:** 1.0.0 | **Platform:** Flutter (Android · iOS · Web · Windows · Linux · macOS) | **Backend:** Supabase PostgreSQL

---

## Table of Contents
1. [System Overview](#1-system-overview)
2. [Technology Stack](#2-technology-stack)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [Module Reference](#4-module-reference)
   - 4.1 Authentication
   - 4.2 Dashboard
   - 4.3 Client Management
   - 4.4 Voucher Management
   - 4.5 Point of Sale (POS)
   - 4.6 Sales History
   - 4.7 Package Management
   - 4.8 Sites Management
   - 4.9 Assets Management
   - 4.10 ISP Subscriptions
   - 4.11 Maintenance Management
   - 4.12 Finance & Reporting
   - 4.13 Expenses
   - 4.14 Investors
   - 4.15 SMS Management
   - 4.16 Commission System
   - 4.17 User Management
   - 4.18 Settings
5. [Database Schema](#5-database-schema)
6. [Automation & Business Logic](#6-automation--business-logic)
7. [Security Architecture](#7-security-architecture)
8. [Navigation Structure](#8-navigation-structure)

---

## 1. System Overview

**ViorNet** is a comprehensive, multi-platform ISP (Internet Service Provider) business management system built for WiFi resellers and small ISPs. It enables businesses to manage their entire operation from a single application — from selling internet vouchers and tracking clients, to managing infrastructure, recording expenses, calculating agent commissions, and monitoring investor returns.

### What the System Does

| Area | Capability |
|------|------------|
| Sales | Sell internet vouchers via POS, track all transactions, manage payment methods |
| Clients | Full client lifecycle management with expiry tracking and SMS reminders |
| Vouchers | Batch import/generate, QR code support, multi-status tracking |
| Sites | Manage multiple network sites/hotspots across different locations |
| Finance | Revenue dashboard, expense tracking, profit/loss reporting |
| Infrastructure | Track routers, APs, switches, and equipment per site |
| Maintenance | Log, assign, and track technical jobs with priority levels |
| ISP Billing | Record uplink subscription payments; auto-generate INTERNET expenses |
| Commissions | Configurable agent commission rules (%, fixed, or tiered) |
| Investors | Track investor portfolios with ROI calculated from net profit |
| SMS | Send bulk/individual SMS to clients with templates and scheduling |
| Users | Multi-user with role-based access control |

---

## 2. Technology Stack

### Frontend
| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.x (Dart SDK ^3.5.4) |
| State Management | Riverpod 2.5.1 |
| Navigation | GoRouter 14.2.7 (ShellRoute with persistent sidebar) |
| UI Toolkit | Material 3, Google Fonts (Poppins) |
| Charts | fl_chart 0.69.0 |
| QR Code | qr_flutter + mobile_scanner |
| PDF/Print | pdf + printing packages |
| Responsive | flutter_screenutil (design size 375×812) |
| Animations | flutter_animate |

### Backend & Data
| Component | Technology |
|-----------|-----------|
| Database | Supabase PostgreSQL (cloud-native, no local SQLite) |
| Auth Layer | Custom SHA-256 hashed passwords stored in `users` table |
| Secure Storage | flutter_secure_storage (remember-me, session tokens) |
| File Operations | file_picker, share_plus, open_file |
| SMS | Native Android SMS via sms_manager_service |
| Network | Dio + http for any REST calls |

### Supported Platforms
- ✅ Android (primary)
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

---

## 3. User Roles & Permissions

The system implements a full Role-Based Access Control (RBAC) system. Every screen and action is gated by role.

### Roles

| Role | ID | Description |
|------|----|-------------|
| Super Admin | `SUPER_ADMIN` | Unrestricted access to all features |
| Admin | `ADMIN` | Full operational access (not super-admin controls) |
| Finance | `FINANCE` | Financial data, expenses, investors, sales views |
| Marketing | `MARKETING` | Client management, vouchers, SMS |
| Sales | `SALES` | POS, sales history, client creation |
| Technical | `TECHNICAL` | Sites, assets, maintenance management |
| Agent | `AGENT` | POS only, own commissions, limited view |

### Permission Matrix

| Module | SUPER_ADMIN | ADMIN | FINANCE | MARKETING | SALES | TECHNICAL | AGENT |
|--------|:-----------:|:-----:|:-------:|:---------:|:-----:|:---------:|:-----:|
| Dashboard | ✅ Full | ✅ Full | ✅ Finance | ✅ Basic | ✅ Basic | ✅ Basic | ✅ Own |
| Clients — View | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Clients — Create | ✅ | ✅ | — | ✅ | ✅ | — | — |
| Clients — Edit | ✅ | ✅ | — | ✅ | — | — | — |
| Clients — Delete | ✅ | ✅ | — | — | — | — | — |
| Vouchers — View | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vouchers — Create | ✅ | ✅ | — | ✅ | — | — | ✅ |
| Vouchers — Delete | ✅ | ✅ | ✅ | — | — | — | — |
| POS / Make Sale | ✅ | ✅ | — | — | ✅ | — | ✅ |
| Sales — View | ✅ | ✅ | ✅ | — | ✅ | — | — |
| Sales — Edit/Delete | ✅ | ✅ | ✅ | — | — | — | — |
| Sites — View | ✅ | ✅ | — | ✅ | ✅ | ✅ | — |
| Sites — Manage | ✅ | ✅ | — | — | — | ✅ | — |
| Assets | ✅ | ✅ | — | — | — | ✅ | — |
| Maintenance | ✅ | ✅ | — | — | — | ✅ | — |
| Finance Dashboard | ✅ | ✅ | ✅ | — | — | — | — |
| Expenses — Manage | ✅ | ✅ | ✅ | — | — | — | — |
| Investors — Manage | ✅ | ✅ | ✅ | — | — | — | — |
| ISP Subscriptions | ✅ | ✅ | ✅ | — | — | — | — |
| SMS | ✅ | ✅ | — | ✅ | — | — | — |
| Packages — View | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| Packages — Manage | ✅ | ✅ | — | — | — | — | — |
| Users — View | ✅ | ✅ | — | — | — | — | — |
| Users — Manage | ✅ | ✅ | — | — | — | — | — |
| Commissions — Config | ✅ | ✅ | ✅ | — | — | — | — |
| My Commissions | ✅ | ✅ | — | — | ✅ | — | ✅ |
| Settings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |

---

## 4. Module Reference

---

### 4.1 Authentication

**Route:** `/login`  
**Accessible by:** Everyone (unauthenticated)

#### Features
- **Email + Password login** with SHA-256 hashed password verification
- **Remember Me** — stores email in secure storage for next login
- **Animated login screen** with glassmorphism UI and animated background
- **Error handling** — shows glass alert dialog on failed login with specific error message
- **Auto-redirect** — authenticated users are redirected to dashboard; unauthenticated users redirected to login
- **Session persistence** — auth state is restored from secure storage on app start
- **Default admin seeded** — on first launch, `admin@viornet.com` / `admin123` is created automatically if no admin exists
- **User registration** screen available at `/register`

---

### 4.2 Dashboard

**Route:** `/`  
**Accessible by:** All authenticated users (content varies by role)

#### Features
- **KPI Stats Cards** (grid layout, responsive — 2 columns on mobile, 3–4 on tablet):
  - Total Clients (count)
  - Active Vouchers (count)
  - Today's Sales (amount) — *hidden from AGENT role*
  - Total Revenue — *hidden from AGENT role*
- **7-Day Sales Chart** — line/bar chart showing daily revenue trend (fl_chart)
- **Agent Commission Widget** — visible to AGENT and SALES roles; shows their own earned commissions and recent sales
- **Recent Sales List** — last transactions with receipt number, amount, and payment method
- **Voucher Status Summary** — breakdown of Active / Sold / Expired / Unused vouchers
- **Role-aware content** — financial data hidden from Agent role; agents only see their own activity
- **Pull-to-refresh** — live data refresh from Supabase
- **Responsive layout** — adapts between mobile and tablet breakpoints

---

### 4.3 Client Management

**Route:** `/clients`  
**Accessible by:** All roles (CRUD gated by role)

#### Features
- **Client list** with search by name/phone/email
- **Client detail page** (`/clients/:id`) — full profile view
- **Create client** (ADMIN, SUPER_ADMIN, MARKETING, SALES):
  - Name, phone (required), email, address
  - Site assignment
  - MAC address for device tracking
  - SMS reminder opt-in toggle
  - Notes
- **Edit client** (ADMIN, SUPER_ADMIN, MARKETING) — modify all fields
- **Delete client** (ADMIN, SUPER_ADMIN only) — with confirmation dialog
- **Expiry tracking** — clients have an `expiry_date`; system tracks last purchase date
- **Active/Inactive status** toggle
- **Client ownership** — clients can be linked to the selling agent via `client_id` in sales

---

### 4.4 Voucher Management

**Route:** `/vouchers`  
**Accessible by:** All roles (operations gated by role)

#### Features

**Two-tab layout:**

**Tab 1 — Vouchers**
- Full list with status filters: ALL / ACTIVE / SOLD / EXPIRED / UNUSED
- Filter by **package type**, **site**, and **batch**
- **Search** by voucher code, username, or client name
- **Multi-select mode** — long-press to select multiple vouchers for bulk delete
- **Summary bar** (ADMIN/FINANCE only) — total count, total value, revenue earned
- Per-voucher actions:
  - **Edit** — modify price, duration, status, assign to client/site (ADMIN/FINANCE/SUPER_ADMIN)
  - **Delete** single (ADMIN/FINANCE/SUPER_ADMIN)
  - **Bulk delete** selected (ADMIN/FINANCE/SUPER_ADMIN)

**Tab 2 — Batch Import (CSV)**
- **Import vouchers from CSV file** — map columns for code, username, password, duration, price
- Validates and bulk-inserts with a `batch_id` for tracking
- Download/view imported batches

**Additional Voucher Capabilities:**
- Each voucher has: `code`, `username`, `password`, `duration` (days), `price`, `status`, `site_id`, `batch_id`, `qr_code_data`
- Status lifecycle: UNUSED → ACTIVE → SOLD → EXPIRED
- `created_at`, `sold_at`, `activated_at`, `expires_at` timestamps tracked

---

### 4.5 Point of Sale (POS)

**Route:** `/pos`  
**Accessible by:** SUPER_ADMIN, ADMIN, SALES, AGENT

#### Features
- **Sale Type Toggle:** Voucher Sale or Package Sale
- **Walk-In Mode** — sell without a registered client; create new client inline
- **Client search and selection** — autocomplete from existing active clients
- **Quick new client form** — name, phone, email without leaving POS
- **Site selection** — choose which site the sale is for
- **Package selection** — pick from active packages
- **Voucher search** — find available (UNUSED/ACTIVE) vouchers by code
- **Payment methods:** CASH, MPESA, BANK, CARD, OTHER
- **Amount + commission** entry
- **Receipt generation** — unique auto-generated receipt number
- **Instant sale recording** to Supabase with all relational data
- **Agent attribution** — sale automatically linked to logged-in agent
- **Voucher status update** — voucher marked SOLD on completion

---

### 4.6 Sales History

**Route:** `/sales`  
**Accessible by:** SUPER_ADMIN, ADMIN, FINANCE, SALES

#### Features
- **Full sales list** with real-time search (receipt number, client name)
- **Date range filter** — pick start and end dates to narrow results
- **Payment method filter** — filter by CASH / MPESA / BANK / CARD / OTHER
- **Per-payment-method color coding** and icons
- **Summary bar** — total sales count and total revenue for current filter
- **Edit Sale** (ADMIN, SUPER_ADMIN, FINANCE):
  - Change amount, payment method, commission, notes
  - With confirmation dialog
- **Delete Sale** (ADMIN, SUPER_ADMIN, FINANCE):
  - With confirmation dialog; irreversible warning shown
- **Pull-to-refresh** for live updates
- Sale detail shows: receipt number, date/time, client name, agent, site, voucher code, amount, payment method, commission

---

### 4.7 Package Management

**Route:** `/packages`  
**Accessible by:** All roles (management gated to ADMIN/SUPER_ADMIN)

#### Features
- **Default packages auto-seeded** on first launch:
  - 1 Week — 5,000
  - 2 Weeks — 9,000
  - 1 Month — 15,000
  - 3 Months — 40,000
- **Create custom packages** with name, duration (days), price, and description
- **Edit packages** — modify price, duration, description
- **Activate/Deactivate** packages without deleting
- **Delete packages** — with confirmation
- Packages are selectable in POS and commission rules

---

### 4.8 Sites Management

**Route:** `/sites`  
**Accessible by:** SUPER_ADMIN, ADMIN, MARKETING, SALES, TECHNICAL

#### Features
- **Site list** with search by name or location
- **Add/Edit site** form:
  - Name, location, GPS coordinates
  - Router IP, username, password
  - Contact person and contact phone
  - Active/Inactive toggle
- **Delete site** — with confirmation
- **Per-site drill-down** — each site card links to:
  - ISP Subscription screen for that site
  - Client list filtered by site
  - Asset list filtered by site
  - Maintenance records for that site
- **User–Site assignments** — users can be restricted to specific sites

---

### 4.9 Assets Management

**Route:** `/assets`  
**Accessible by:** SUPER_ADMIN, ADMIN, TECHNICAL

#### Features
- **Asset list** with search and type filter chips: ROUTER / AP / SWITCH / UPS / OTHER
- **Add asset** dialog:
  - Name, type, serial number, model, manufacturer
  - Site assignment
  - Purchase date, purchase price
  - Warranty expiry date
  - Condition (GOOD / FAIR / POOR / DAMAGED)
  - Location, notes
- **Edit asset** — update all fields including condition
- **Active/Inactive status** toggle
- Assets are linked to sites and can be referenced in maintenance records

---

### 4.10 ISP Subscriptions

**Route:** `/isp-subscription` (per site — `/isp-subscription/:siteId`)  
**Accessible by:** SUPER_ADMIN, ADMIN, TECHNICAL, FINANCE

#### Features
- **Per-site subscription history** — all uplink payments for a specific site
- **Summary cards** at top: Total Payments count, Total Amount Paid, Next Due Date
- **Next due date** card with countdown urgency indicator (red if expired/near)
- **Add new subscription:**
  - Provider name (required)
  - Payment control number, registered name, service number
  - Paid date, ends/expiry date
  - Amount, notes
- **Edit existing subscription**
- **Delete subscription** — with confirmation
- **Auto-expense recording** *(automation)*: When a new ISP subscription is added with an amount > 0, the system **automatically creates an INTERNET expense** in the expenses table. This means every ISP payment is reflected in the financial reports without manual double-entry. The auto-recorded expense includes:
  - Category: `INTERNET`
  - Description: `ISP - [Provider Name]`
  - Amount: same as subscription amount
  - Site: same site as the subscription
  - Date: the `paid_at` date
  - Created by: the logged-in user
- **ISP Overview screen** (`/isp-subscription`) — cross-site view of all subscriptions

---

### 4.11 Maintenance Management

**Route:** `/maintenance`  
**Accessible by:** SUPER_ADMIN, ADMIN, TECHNICAL

#### Features
- **Maintenance record list** with combined filters:
  - Status filter: ALL / PENDING / IN_PROGRESS / COMPLETED / CANCELLED
  - Priority filter: ALL / LOW / MEDIUM / HIGH / CRITICAL
  - Site filter dropdown
- **Create maintenance record:**
  - Title and description
  - Priority level (LOW / MEDIUM / HIGH / CRITICAL)
  - Initial status
  - Site and asset linkage
  - Reporter (auto-set to logged-in user)
  - Assigned technician
  - Scheduled date
  - Cost estimate
  - Resolution notes
- **Edit/update records** — change status through lifecycle
- **Delete records** — with confirmation
- **Status tracking**: PENDING → IN_PROGRESS → COMPLETED (or CANCELLED)
- Cost tracking per maintenance job

---

### 4.12 Finance & Reporting

**Route:** `/finance`  
**Accessible by:** SUPER_ADMIN, ADMIN, FINANCE

#### Features
- **Date range selector** — custom start and end date picker
- **Financial Summary Cards:**
  - Total Revenue (from sales)
  - Total Expenses (from expenses table)
  - Net Profit (Revenue − Expenses)
  - This Month's Revenue
  - This Month's Expenses
  - This Month's Profit
- **Revenue vs Expenses Comparison** — side-by-side display for the selected period
- **Recent Transactions list** — latest sales with amount and date
- **Expense Breakdown by Category** — shows spend per category (MAINTENANCE, EQUIPMENT, SALARY, UTILITY, FUEL, RENT, INTERNET, OTHER)
- **Quick link to Expenses screen** — button in app bar to manage individual expenses
- **Pull-to-refresh** live data re-fetching

---

### 4.13 Expenses

**Route:** `/expenses`  
**Accessible by:** SUPER_ADMIN, ADMIN, FINANCE

#### Features
- **Full CRUD expense management**
- **Expense list** showing all recorded expenses
- **Category filter** — filter by: MAINTENANCE / EQUIPMENT / SALARY / UTILITY / FUEL / RENT / INTERNET / OTHER
- **Color-coded category badges** with category-specific icons
- **Add expense** dialog:
  - Category (dropdown, required)
  - Description (required)
  - Amount (required)
  - Expense date (date picker, defaults to today)
  - Site assignment (optional, links expense to a site)
  - Receipt number (optional)
  - Notes (optional)
- **Edit expense** — modify all fields (ADMIN/FINANCE/SUPER_ADMIN)
- **Delete expense** — with confirmation (ADMIN/FINANCE/SUPER_ADMIN)
- **Summary header** — total expenses shown above list
- Color-coded by category (e.g., INTERNET = indigo, SALARY = green, FUEL = red)
- **Auto-created expenses** appear here when ISP subscriptions are added

---

### 4.14 Investors

**Route:** `/investors`  
**Accessible by:** SUPER_ADMIN, ADMIN, FINANCE

#### Features
- **Investor portfolio list** — all investors with key metrics per card
- **Business-wide financial summary** at top:
  - Total Revenue
  - Total Expenses
  - Net Profit (calculated live from all sales minus all expenses)
- **Per-investor ROI calculation:**
  - Each investor has a configured `roi_percentage` (% of net profit)
  - System calculates: `investor return = net_profit × (roi_percentage / 100)`
  - Displayed per return period (MONTHLY / QUARTERLY / ANNUALLY)
- **Investor cards show:**
  - Investor name, contact info
  - Invested amount
  - ROI percentage
  - Return period
  - Calculated return amount based on current net profit
  - Active/Inactive status badge
  - Investment date
- **Add investor** dialog (ADMIN/FINANCE/SUPER_ADMIN):
  - Name (required)
  - Email, phone
  - Invested amount
  - Investment date
  - ROI percentage (e.g., `5.000` = 5% of net profit)
  - Return period: MONTHLY / QUARTERLY / ANNUALLY
  - Notes
  - Active status toggle (for existing investors)
- **Edit investor** — modify all fields
- **Delete investor** — with confirmation dialog
- **Role gate** — only ADMIN, SUPER_ADMIN, FINANCE can see/use this module

---

### 4.15 SMS Management

**Route:** `/sms`  
**Accessible by:** SUPER_ADMIN, ADMIN, MARKETING

#### Four-tab interface:

**Tab 1 — Send SMS**
- Individual or bulk SMS composition
- Recipient selection from client database
- Free-text message composition
- Schedule SMS for future delivery
- Send immediately

**Tab 2 — Templates**
- Create SMS templates with name, message text, and type
- Template types for different occasions (expiry reminders, promotions, etc.)
- Activate/deactivate templates
- Use templates in quick-send flow

**Tab 3 — Contacts**
- Browse clients as SMS contacts
- Filter by site
- Filter by contact type (All / Active / Expiring / Expired)
- Select individual or multiple contacts for SMS

**Tab 4 — SMS Logs**
- Full history of all sent SMS messages
- Status tracking: SENT / FAILED / PENDING
- Timestamp, recipient, message content, error messages if failed
- Filter and search logs

---

### 4.16 Commission System

**Routes:** `/settings/commissions` (configuration), `/my-commissions` (agent view), `/commission-demands`

#### Commission Configuration (ADMIN / FINANCE)
- **Configurable commission rules** with multiple rule types:
  - `PERCENTAGE` — percentage of sale amount
  - `FIXED_AMOUNT` — flat amount per sale
  - `TIERED` — different rates for different sale amount ranges
- **Applicability scoping:**
  - `ALL_AGENTS` — applies to every agent
  - `SPECIFIC_ROLE` — only agents with a certain role
  - `SPECIFIC_USER` — only one specific agent
  - `SPECIFIC_CLIENT` — only sales to a specific client
  - `SPECIFIC_PACKAGE` — only sales of a specific package
- **Priority ordering** — higher priority rules override lower ones
- **Date ranges** — commission rules can have start/end dates (time-limited promotions)
- **Minimum sale amount** threshold required to qualify
- **Default rule:** 10% for all agents; bonus 5% for sales above 100,000

#### Agent Commission View (`/my-commissions`)
- Agents see only their own commission history
- Status: PENDING / APPROVED / PAID / CANCELLED
- Amount earned per sale, sale amount, date
- Approval and payment timestamp tracking

#### Commission Demands (`/commission-demands`)
- Agents can submit demand/request for commission payout
- Admin/Finance can review, approve, or reject demands
- Approval triggers `APPROVED` status in commission history

---

### 4.17 User Management

**Route:** `/users`  
**Accessible by:** SUPER_ADMIN, ADMIN

#### Features
- **User list** with role filter: ALL / SUPER_ADMIN / MARKETING / SALES / TECHNICAL / FINANCE / AGENT
- **Create user** (FAB button):
  - Full name, email (unique), phone
  - Password (SHA-256 hashed before storage)
  - Role assignment
  - Active status
- **Edit user** — update name, phone, email, role, status
- **Delete user** (ADMIN/SUPER_ADMIN only) — with confirmation; cannot delete yourself
- **Role badge** color-coded on each user card
- **Active/Inactive** visual indicator

---

### 4.18 Settings

**Route:** `/settings`  
**Accessible by:** All authenticated users (sections gated by role)

#### Sections

**Account**
- Profile Settings *(coming soon)*
- Change Password *(coming soon)*

**Administration** *(ADMIN / SUPER_ADMIN)*
- → User Management (`/users`)
- → Package Management (`/packages`)
- → Commission Settings (`/settings/commissions`)
- → Commission Demands (`/commission-demands` or `/settings/commission-demands`)

**System** *(ADMIN / SUPER_ADMIN)*
- System configuration options

**General** *(All users)*
- Notifications settings
- About dialog — shows app name, version, and description

---

## 5. Database Schema

All data is stored in **Supabase PostgreSQL**. There is no local SQLite — all reads and writes go directly to the cloud database using the service-role key (bypassing Row Level Security for reliability).

### Tables

#### `users`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| server_id | UUID UNIQUE | Auto-generated |
| name | TEXT NOT NULL | |
| email | TEXT UNIQUE NOT NULL | Login identifier |
| phone | TEXT | |
| role | TEXT NOT NULL | Primary role string |
| password_hash | TEXT NOT NULL | SHA-256 hash |
| is_active | BOOLEAN | Default: true |
| created_at, updated_at | TIMESTAMP | Auto-managed |

#### `sites`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name | TEXT NOT NULL | |
| location | TEXT | |
| gps_coordinates | TEXT | |
| router_ip | TEXT | |
| router_username / password | TEXT | |
| contact_person, contact_phone | TEXT | |
| is_active | BOOLEAN | |

#### `clients`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name, phone | TEXT NOT NULL | |
| email, address | TEXT | |
| mac_address | TEXT | Device tracking |
| site_id | FK → sites | |
| registration_date | TIMESTAMP NOT NULL | |
| last_purchase_date, expiry_date | TIMESTAMP | |
| is_active | BOOLEAN | |
| sms_reminder | BOOLEAN | |
| notes | TEXT | |

#### `vouchers`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| code | TEXT UNIQUE NOT NULL | |
| username, password | TEXT | MikroTik credentials |
| duration | INTEGER NOT NULL | Days |
| price | DECIMAL(10,2) NOT NULL | |
| status | TEXT NOT NULL | UNUSED/ACTIVE/SOLD/EXPIRED |
| site_id | FK → sites | Added in migration 006 |
| batch_id | VARCHAR(36) | Added in migration 006 |
| qr_code_data | TEXT | Added in migration 006 |
| agent_id | FK → users | |
| client_id | FK → clients | |
| sold_at, activated_at, expires_at | TIMESTAMP | |

#### `sales`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| receipt_number | TEXT UNIQUE NOT NULL | |
| voucher_id | FK → vouchers NOT NULL | |
| client_id | FK → clients | |
| agent_id | FK → users NOT NULL | |
| site_id | FK → sites | |
| amount | DECIMAL(10,2) NOT NULL | |
| commission | DECIMAL(10,2) | Default: 0 |
| payment_method | TEXT NOT NULL | CASH/MPESA/BANK/CARD/OTHER |
| notes | TEXT | |
| sale_date | TIMESTAMP NOT NULL | |

#### `expenses`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| category | TEXT NOT NULL | MAINTENANCE/EQUIPMENT/SALARY/UTILITY/FUEL/RENT/INTERNET/OTHER |
| description | TEXT NOT NULL | |
| amount | DECIMAL(10,2) NOT NULL | |
| site_id | FK → sites | Optional |
| created_by | FK → users NOT NULL | |
| expense_date | TIMESTAMP NOT NULL | |
| receipt_number | TEXT | |
| notes | TEXT | |

#### `assets`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name, type | TEXT NOT NULL | |
| serial_number, model, manufacturer | TEXT | |
| site_id | FK → sites | |
| purchase_date, warranty_expiry | TIMESTAMP | |
| purchase_price | DECIMAL(10,2) | |
| condition | TEXT NOT NULL | GOOD/FAIR/POOR/DAMAGED |
| is_active | BOOLEAN | |

#### `maintenance`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| title, description | TEXT NOT NULL | |
| priority | TEXT NOT NULL | LOW/MEDIUM/HIGH/CRITICAL |
| status | TEXT NOT NULL | PENDING/IN_PROGRESS/COMPLETED/CANCELLED |
| site_id | FK → sites | |
| asset_id | FK → assets | |
| reported_by | FK → users NOT NULL | |
| assigned_to | FK → users | |
| scheduled_date, completed_date | TIMESTAMP | |
| cost | DECIMAL(10,2) | |
| resolution, notes | TEXT | |

#### `packages`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name | TEXT NOT NULL | |
| duration | INTEGER NOT NULL | Days |
| price | DECIMAL(10,2) NOT NULL | |
| description | TEXT | |
| is_active | BOOLEAN | |

#### `sms_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| recipient | TEXT NOT NULL | Phone number |
| message | TEXT NOT NULL | |
| status | TEXT NOT NULL | SENT/FAILED/PENDING |
| type | TEXT NOT NULL | |
| client_id | FK → clients | |
| scheduled_at, sent_at | TIMESTAMP | |
| error_message | TEXT | |

#### `sms_templates`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name | TEXT NOT NULL | |
| message | TEXT NOT NULL | |
| type | TEXT NOT NULL | |
| is_active | BOOLEAN | |

#### `commission_settings`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name, description | TEXT | |
| commission_type | TEXT | PERCENTAGE/FIXED_AMOUNT/TIERED |
| rate | DECIMAL(10,2) | % or flat amount |
| min_sale_amount | DECIMAL(10,2) | Qualification threshold |
| applicable_to | TEXT | ALL_AGENTS/SPECIFIC_ROLE/SPECIFIC_USER/SPECIFIC_CLIENT/SPECIFIC_PACKAGE |
| role_id, user_id, client_id, package_id | FK | Scope targets |
| priority | INTEGER | Higher = applied first |
| start_date, end_date | TIMESTAMP | Time-bound rules |
| is_active | BOOLEAN | |

#### `commission_history`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| sale_id | FK → sales | |
| agent_id | FK → users NOT NULL | |
| commission_amount | DECIMAL(10,2) NOT NULL | |
| sale_amount | DECIMAL(10,2) NOT NULL | |
| commission_setting_id | FK → commission_settings | |
| commission_rate | DECIMAL(10,2) | Rate at time of calculation |
| calculation_details | JSONB | Full audit trail |
| status | TEXT | PENDING/APPROVED/PAID/CANCELLED |
| approved_by | FK → users | |
| approved_at, paid_at | TIMESTAMP | |

#### `isp_subscriptions`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| site_id | FK → sites NOT NULL | |
| provider_name | VARCHAR(255) NOT NULL | |
| payment_control_number | VARCHAR(255) | |
| registered_name | VARCHAR(255) | |
| service_number | VARCHAR(255) | |
| paid_at | TIMESTAMPTZ NOT NULL | |
| ends_at | TIMESTAMPTZ NOT NULL | |
| amount | NUMERIC(12,2) | |
| notes | TEXT | |

#### `investors`
| Column | Type | Notes |
|--------|------|-------|
| id | SERIAL PK | |
| name | TEXT NOT NULL | |
| email, phone | TEXT | |
| invested_amount | NUMERIC(15,2) | |
| invest_date | DATE NOT NULL | |
| roi_percentage | NUMERIC(6,3) | % of net profit |
| return_period | TEXT | MONTHLY/QUARTERLY/ANNUALLY |
| notes | TEXT | |
| is_active | BOOLEAN | Default: true |

#### Relationship Tables
- **`user_roles`** — Many-to-many: users ↔ roles
- **`user_sites`** — Many-to-many: users ↔ sites (site access restriction)
- **`roles`** — Reference table: SUPER_ADMIN, ADMIN, AGENT, TECHNICIAN, etc.

---

## 6. Automation & Business Logic

### ISP Subscription → Automatic Expense Recording

When a **new** ISP subscription is saved (not an edit), the system automatically:
1. Saves the ISP subscription record
2. Creates an `INTERNET` category expense with:
   - Description: `"ISP - [Provider Name]"`
   - Amount: same as subscription amount
   - Site: same site as the subscription
   - Expense date: the `paid_at` date of the subscription
   - Notes: subscription notes (prefixed with "Auto-recorded from ISP subscription.")
   - Created by: logged-in user's ID
3. Shows a snackbar: *"ISP subscription added and expense recorded automatically"*

This eliminates double-entry: the ISP uplink cost is automatically captured in the Finance/Expenses module — no separate expense entry needed.

---

### Commission Auto-Calculation

When a sale is recorded at POS:
1. The system evaluates all active `commission_settings` rules ordered by priority
2. The highest-priority applicable rule is applied
3. Commission amount is calculated (percentage or fixed)
4. A `commission_history` record is created with status `PENDING`
5. Admin/Finance approves → status becomes `APPROVED`
6. After payment → status becomes `PAID`

---

### Voucher Status Lifecycle

```
UNUSED → ACTIVE (when assigned to client) → SOLD (when POS sale recorded) → EXPIRED (when duration elapses)
```

---

### Default Package Seeding

On first launch, if no packages exist in the database, the system auto-creates four default packages:
- 1 Week / 5,000
- 2 Weeks / 9,000
- 1 Month / 15,000
- 3 Months / 40,000

---

### Investor ROI Calculation

The Investors screen fetches:
- `totalRevenue` = sum of all sales amounts
- `totalExpenses` = sum of all expense amounts
- `netProfit` = totalRevenue − totalExpenses

For each investor:
```
investorReturn = netProfit × (roiPercentage / 100)
```
Display is per investor's chosen return period (MONTHLY/QUARTERLY/ANNUALLY).

---

## 7. Security Architecture

### Authentication
- Passwords stored as **SHA-256 hashes** — never in plain text
- Session stored in `flutter_secure_storage` (platform keystore)
- "Remember Me" only stores the email, never the password
- Session integrity checked on app start; invalid/expired sessions redirect to login

### Database Access
- Uses **Supabase service-role key** — full database access bypassing RLS
- RLS policies are defined on tables (SELECT for authenticated users; CRUD for admin/finance roles) but the service-role key bypasses them — all authorization is enforced at the **Flutter application layer**
- Route-level permission checks using `PermissionChecker.canAccessRoute(path)`
- Widget-level permission checks using `authState.userRoles` before showing CRUD buttons

### Role Enforcement
Every CRUD action (create/edit/delete buttons, FABs, dialogs) is conditionally rendered based on:
```dart
final canManage = authState.userRoles.any((r) => ['ADMIN', 'SUPER_ADMIN', 'FINANCE'].contains(r));
```
Unauthorized users never see buttons they cannot use.

---

## 8. Navigation Structure

The app uses a **ShellRoute** (persistent sidebar/bottom nav) wrapping all authenticated routes. Navigation items are filtered by the logged-in user's permissions.

```
/splash                     → Splash screen (checks auth state)
/login                      → Login screen
/register                   → Register screen

[ShellRoute — MainLayout]
  /                         → Dashboard
  /clients                  → Client list
    /clients/:id            → Client detail
  /vouchers                 → Voucher management
  /pos                      → Point of Sale
  /sales                    → Sales history
  /my-commissions           → Agent commission view
  /packages                 → Package management
  /sites                    → Sites list
  /assets                   → Assets management
  /isp-subscription         → ISP subscription overview (all sites)
    /isp-subscription/:id   → Per-site ISP subscriptions
  /maintenance              → Maintenance records
  /finance                  → Finance dashboard
  /expenses                 → Expense management
  /investors                → Investor management & ROI
  /sms                      → SMS management
  /users                    → User management
  /commission-demands       → Commission demand requests
  /settings                 → Settings
    /settings/commissions   → Commission configuration
    /settings/commission-demands → Commission demands (alt route)
```

### Navigation Sidebar Items (filtered by role)
1. Dashboard
2. Clients
3. Vouchers
4. Packages
5. POS
6. Sales
7. My Commissions
8. Sites
9. Assets
10. ISP Subscription
11. Maintenance
12. Finance
13. Expenses
14. Investors
15. Commission Demands
16. SMS
17. Settings

---

## Quick Reference: Default Login

| Field | Value |
|-------|-------|
| Email | `admin@viornet.com` |
| Password | `admin123` |
| Role | SUPER_ADMIN |

> ⚠️ Change the default password immediately after first login in a production deployment.

---

*Documentation generated: February 24, 2026*  
*System: ViorNet v1.0.0 — ISP Management Platform*  
*Repository: Stark-Priver/pritech-viornet*
