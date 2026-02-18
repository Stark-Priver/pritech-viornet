<div align="center">

<img src="https://img.shields.io/badge/Version-1.0-2E75B6?style=for-the-badge" alt="Version 1.0"/>
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-1A3C6B?style=for-the-badge" alt="Platform"/>
<img src="https://img.shields.io/badge/Stack-Flutter%20%2B%20Django-4A90C4?style=for-the-badge" alt="Stack"/>
<img src="https://img.shields.io/badge/Status-In%20Development-orange?style=for-the-badge" alt="Status"/>

# ViorNet

### WiFi Reseller & ISP Management System

*A fully offline-first platform for automating WiFi reseller operations — voucher sales, client management, site monitoring, equipment tracking, SMS notifications, and financial reporting.*

**Author:** Privertus Cosmas &nbsp;|&nbsp; **Organization:** Pritech Vior Softech &nbsp;|&nbsp; **Version:** 1.0

---

</div>

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Functional Requirements](#functional-requirements)
  - [Authentication](#41-authentication)
  - [Sites Management](#42-sites-management)
  - [Client Management](#43-client-management)
  - [Voucher Management](#44-voucher-management)
  - [Sales Module](#45-sales-module)
  - [Finance Module](#46-finance-module)
  - [Asset Management](#47-asset-management)
  - [Maintenance Module](#48-maintenance-module)
  - [SMS Module](#49-sms-module-android-only)
  - [MikroTik Integration](#410-mikrotik-integration)
- [Non-Functional Requirements](#non-functional-requirements)
- [Database Design](#database-design)
- [Offline Sync Strategy](#offline-sync-strategy)
- [User Workflows](#user-workflows)
- [UI Structure](#ui-structure)
- [Future Enhancements](#future-enhancements)
- [Definitions](#definitions)

---

## Overview

ViorNet is an **offline-first WiFi reseller and ISP management system** built with Flutter and Django. It is designed to replace manual, paper-based operations with a fully digital, automated platform that functions reliably in low-connectivity environments and synchronizes to the cloud when internet access is restored.

### What ViorNet Automates

| Domain | Capabilities |
|--------|-------------|
| **Sales** | Voucher generation, POS selling, receipts, agent commissions |
| **Clients** | Registration, MAC tracking, expiry monitoring, SMS reminders |
| **Sites** | Multi-site management, router assignment, per-site analytics |
| **Finance** | Expense recording, profit calculation, Excel/PDF exports |
| **Assets** | Equipment tracking, serial numbers, warranty, movement history |
| **Maintenance** | Fault reporting, technician assignment, downtime logging |
| **SMS** | Bulk campaigns, expiry reminders, templates — via device SIM |
| **Network** | MikroTik hotspot integration, user provisioning, traffic stats |

### Target Platforms

| Platform | Target Users |
|----------|-------------|
| **Android** | Agents, field staff, marketing, sales |
| **Windows Desktop** | Administrators, finance, technical teams |

---

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│             Flutter Application                         │
│          (Android / Windows Desktop)                    │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│              Local Database (Offline-First)             │
│              Drift / Isar / Hive                        │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                  Sync Service                           │
│         (Background — triggers on connectivity)        │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│              Django REST API Backend                    │
└──────────────┬────────────────────────┬─────────────────┘
               │                        │
┌──────────────▼──────────┐  ┌──────────▼──────────────────┐
│      PostgreSQL         │  │    MikroTik Routers          │
│      (Primary DB)       │  │    (via routeros_api)        │
└─────────────────────────┘  └─────────────────────────────┘
```

### Architecture Principles

**Frontend (Flutter) is responsible for:**
- All local data storage and CRUD operations
- Voucher generation and point-of-sale transactions
- SMS sending via device SIM card *(Android only)*
- Full offline functionality — every feature works without connectivity
- Background sync when connectivity is detected

**Backend (Django) is responsible for:**
- Centralized data backup and authoritative data store
- Sync coordination and conflict resolution
- Reporting, aggregation, and analytics
- JWT-based authentication and session management
- All MikroTik router communication — *Flutter must never connect directly*

---

## Technology Stack

### Frontend

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| State Management | Riverpod / Bloc |
| Local Database | Drift / Isar / Hive |
| HTTP Client | Dio |
| Navigation | go_router |
| SMS | telephony *(Android only)* |
| App Package | `com.pritechvior.viornet` |

### Backend

| Component | Technology |
|-----------|------------|
| Framework | Django |
| REST API | Django REST Framework (DRF) |
| Database | PostgreSQL |
| MikroTik Integration | routeros_api |
| Task Queue | Celery |

---

## Functional Requirements

### 4.1 Authentication

Secure login/logout with role-based access control enforced across all modules.

| Role | Access Scope |
|------|-------------|
| **Super Admin** | Full system access — all modules, settings, user management |
| **Finance** | Financial reports, expense management, revenue data |
| **Marketing** | SMS campaigns, client filtering, bulk messaging |
| **Sales** | Voucher sales, receipts, daily summaries |
| **Technical** | Asset management, maintenance logs, fault reporting |
| **Agent** | Voucher selling, client SMS reminders |

---

### 4.2 Sites Management

Create and manage multiple physical WiFi locations, each with its own configuration and assigned resources.

- Create and edit sites with name, GPS coordinates, and router credentials
- Assign routers and access points to specific sites
- Assign agents responsible for each site
- View per-site revenue statistics and performance metrics

---

### 4.3 Client Management

Maintain comprehensive client records with automated account lifecycle management.

- Add, edit, and deactivate client profiles
- Store phone numbers and MAC addresses per client
- View full purchase history and active service status
- Track expiry dates and trigger automated SMS reminders

---

### 4.4 Voucher Management

Manage the complete voucher lifecycle from generation through expiry.

#### Voucher Status States

| Status | Description |
|--------|-------------|
| `UNUSED` | Generated but not yet sold |
| `SOLD` | Purchased, not yet activated |
| `ACTIVE` | Client is currently online |
| `EXPIRED` | Service period has ended |

#### Features
- Bulk voucher generation with configurable validity periods
- Offline sale recording — synced to server on reconnect
- Agent-based voucher assignment and accountability tracking
- Expiry-based auto-deactivation via MikroTik integration

---

### 4.5 Sales Module

A point-of-sale (POS) interface for agents and sales staff.

- Sell vouchers with instant on-screen receipt generation
- View daily and weekly sales summaries per agent or site
- Calculate and track agent commissions automatically
- Generate revenue reports filterable by site, agent, or date range

---

### 4.6 Finance Module

End-to-end financial management from expense recording to profit reporting.

- Record and categorize operational expenses per site
- Calculate net profit across sites and organizational periods
- Export financial reports to **Excel** and **PDF** formats

---

### 4.7 Asset Management

Track all network infrastructure and equipment across every site.

#### Tracked Asset Categories

| Category | Examples |
|----------|---------|
| Active Network Equipment | Routers, Access Points, Switches |
| Power Infrastructure | UPS units, batteries, inverters |
| Passive / Cabling | Ethernet cables, fiber runs, patch panels |

#### Features
- Assign assets to specific sites
- Record serial numbers, purchase dates, and warranty expiry
- Track asset movement between sites
- Monitor condition and operational status over time

---

### 4.8 Maintenance Module

Structured fault reporting and resolution tracking for all network assets.

- Report faults against specific assets with issue descriptions
- Assign repair tasks to technical staff
- Log repair activities, parts used, and resolution notes
- Record downtime duration for SLA tracking and performance analysis

---

### 4.9 SMS Module *(Android Only)*

> **Important:** ViorNet uses the device's physical SIM card for all SMS communications. No third-party SMS API or external gateway is used or required.

- Send bulk marketing campaigns to targeted client segments
- Automated expiry reminders based on account status
- Configurable message templates per campaign type
- Full SMS send log with status tracking per message
- Offline queuing — messages are dispatched as soon as the device is active

---

### 4.10 MikroTik Integration

All MikroTik router operations are handled exclusively by the **Django backend** via the `routeros_api` library. The Flutter app has no direct router access.

| Backend Action | Description |
|---------------|-------------|
| Create Hotspot Users | Provision new voucher users on the router |
| Generate Vouchers | Push voucher codes to MikroTik hotspot profiles |
| Disable Expired Users | Automatically deactivate accounts on expiry |
| Fetch Online Users | Retrieve list of currently connected clients |
| Traffic Statistics | Pull bandwidth and session data for reporting |

---

## Non-Functional Requirements

| Category | Requirements |
|----------|-------------|
| **Performance** | Fully functional offline; UI responses under 2 seconds; responsive on Android and Windows |
| **Reliability** | Local database integrity guaranteed; automatic sync retry on failure; last-write-wins conflict resolution |
| **Security** | JWT-based authentication; encrypted password storage; role-based permissions enforced on all API endpoints |
| **Usability** | Professional dashboard UI for desktop; mobile-optimized screens for field agents |
| **Scalability** | Supports 100+ sites and 10,000+ client records without performance degradation |

---

## Database Design

### Core Entities

All tables include the system fields: `created_at`, `updated_at`, `is_synced`, and `last_synced_at` to support offline-first operation and sync tracking.

| Table | Key Fields |
|-------|-----------|
| `users` | `id`, `name`, `role`, `email`, `password_hash` |
| `sites` | `id`, `name`, `gps_coordinates`, `router_ip`, `router_credentials` |
| `clients` | `id`, `name`, `phone`, `mac_address`, `site_id`, `expiry_date` |
| `vouchers` | `id`, `code`, `status`, `agent_id`, `site_id`, `expiry_date` |
| `sales` | `id`, `voucher_id`, `agent_id`, `amount`, `timestamp` |
| `assets` | `id`, `name`, `serial_number`, `category`, `site_id`, `condition`, `warranty_expiry` |
| `maintenance` | `id`, `asset_id`, `issue`, `technician_id`, `resolved_at`, `downtime_minutes` |
| `sms_logs` | `id`, `recipient_phone`, `message`, `status`, `sent_at` |

### Entity Relationships

```
users ──< sales
users ──< vouchers (agent)
users ──< maintenance (technician)

sites ──< clients
sites ──< vouchers
sites ──< assets

vouchers ──< sales

assets ──< maintenance
```

---

## Offline Sync Strategy

ViorNet is designed for environments with unreliable internet connectivity. The sync engine runs as a background service and activates automatically when a connection is detected.

### Sync Flow

```
Device Comes Online
        │
        ▼
Push local unsynced records ──► Backend API
        │
        ▼
Pull server-side updates ◄── Backend API
        │
        ▼
Resolve conflicts (last-write-wins via updated_at)
        │
        ▼
Mark records: is_synced = true, last_synced_at = NOW()
```

### Sync Fields

| Field | Type | Purpose |
|-------|------|---------|
| `is_synced` | Boolean | Flags whether the record has been pushed to the server |
| `last_synced_at` | Timestamp | Records the time of the last successful sync |

### Conflict Resolution

When the same record is modified both locally and on the server, the **latest `updated_at` timestamp wins**. This strategy ensures predictable, deterministic resolution without requiring manual intervention.

---

## User Workflows

### Agent — Selling a Voucher

```
1. Log in to mobile app
        │
        ▼
2. Navigate to Vouchers → Select or generate voucher
        │
        ▼
3. Complete sale → Transaction recorded locally (offline)
        │
        ▼
4. Optionally send SMS receipt to client via device SIM
        │
        ▼
5. Data syncs to backend when connectivity is restored
```

### Marketing — Sending Expiry Reminders

```
1. Open Client Management module
        │
        ▼
2. Filter clients by upcoming expiry date
        │
        ▼
3. Select message template → Target filtered segment
        │
        ▼
4. Initiate bulk SMS send via device SIM
```

### Technician — Reporting and Resolving a Fault

```
1. Open Maintenance module → Report fault on specific asset
        │
        ▼
2. Admin assigns task to a technician
        │
        ▼
3. Technician logs repair activities and parts used
        │
        ▼
4. Fault marked as resolved → Downtime duration recorded
```

---

## UI Structure

### Desktop Application

The desktop interface follows a professional dashboard layout.

```
┌──────────────────────────────────────────────────────────┐
│  Header: Site Switcher | Sync Status | User Profile      │
├─────────────┬────────────────────────────────────────────┤
│             │                                            │
│  Sidebar    │        Main Content Area                   │
│  ─────────  │  ──────────────────────────────────────    │
│  Dashboard  │  Tables, Charts, Forms, Reports            │
│  Clients    │                                            │
│  Vouchers   │                                            │
│  Sales      │                                            │
│  Finance    │                                            │
│  Sites      │                                            │
│  Assets     │                                            │
│  Maintenance│                                            │
│  SMS        │                                            │
│  Settings   │                                            │
│             │                                            │
└─────────────┴────────────────────────────────────────────┘
```

### Mobile Application

```
┌─────────────────────────┐
│  ☰  ViorNet         👤  │  ← Top App Bar
├─────────────────────────┤
│                         │
│     Main Content        │
│                         │
│                         │
├─────────────────────────┤
│  🏠   👥   🎫   📊   ⚙️  │  ← Bottom Navigation
└─────────────────────────┘
```

### Module Access by Role

| Module | Super Admin | Finance | Marketing | Sales | Technical | Agent |
|--------|:-----------:|:-------:|:---------:|:-----:|:---------:|:-----:|
| Dashboard | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Clients | ✅ | — | ✅ | ✅ | — | ✅ |
| Vouchers | ✅ | — | — | ✅ | — | ✅ |
| Sales | ✅ | ✅ | — | ✅ | — | ✅ |
| Finance | ✅ | ✅ | — | — | — | — |
| Sites | ✅ | — | — | — | ✅ | — |
| Assets | ✅ | — | — | — | ✅ | — |
| Maintenance | ✅ | — | — | — | ✅ | — |
| SMS | ✅ | — | ✅ | ✅ | — | ✅ |
| Settings | ✅ | — | — | — | — | — |

---

## Future Enhancements

| Feature | Description | Priority |
|---------|-------------|----------|
| **QR Code Scanning** | Scan voucher QR codes for faster client activation | High |
| **Bluetooth Printing** | Print receipts from the mobile app to portable printers | High |
| **RADIUS Server** | Enterprise-grade AAA authentication integration | Medium |
| **AI Analytics** | Predictive revenue forecasting and churn detection | Medium |
| **Auto Device Monitoring** | Real-time alerting for router and AP status changes | Medium |
| **Cloud Dashboard** | Web-based management portal for Super Admins | Low |

---

## Definitions

| Term | Definition |
|------|------------|
| **Site** | A physical WiFi location managed within the system |
| **Agent** | An authorized person responsible for selling vouchers |
| **Voucher** | A unique code granting internet access to an end user |
| **Asset** | Network equipment such as access points, routers, or UPS units |
| **Client** | An end user who purchases internet access via a voucher |
| **Offline-First** | The system functions fully without an active internet connection |
| **Sync** | Uploading local data and downloading server updates when connectivity is restored |
| **MikroTik** | Network hardware brand used for hotspot and router management |
| **routeros_api** | Python library for programmatic communication with MikroTik devices |
| **JWT** | JSON Web Token — used for secure, stateless authentication |

---

<div align="center">

*ViorNet — ISP ERP · CRM · Billing · Inventory · Network Monitoring*

**Pritech Vior Softech** &nbsp;|&nbsp; Version 1.0 &nbsp;|&nbsp; Confidential

</div>
