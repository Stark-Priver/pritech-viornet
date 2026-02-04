📘 ViorNet System Documentation
WiFi Reseller & ISP Management System
Version 1.0
Author: Privertus Cosmas
Organization: Pritech Vior Softech
1. Introduction
1.1 Purpose

This document describes the design and requirements for ViorNet, an offline-first WiFi reseller and ISP management system built using Flutter and Django.

The system automates:

voucher sales

client management

site monitoring

equipment tracking

SMS notifications

financial reporting

MikroTik hotspot integration

It replaces manual paper-based operations.

1.2 Scope

ViorNet will:

✅ manage multiple WiFi sites
✅ manage agents and staff
✅ generate and track vouchers
✅ send SMS reminders using phone SIM
✅ track infrastructure assets
✅ manage maintenance
✅ provide reports and analytics
✅ work offline first
✅ sync when online

Platforms:

Android

Windows Desktop

1.3 Definitions
Term	Meaning
Site	Physical WiFi location
Agent	Person selling vouchers
Voucher	Internet access code
Asset	Equipment like AP/router
Client	End user
Offline-first	Works without internet
Sync	Data upload/download when online
2. System Architecture
2.1 High-Level Architecture
Flutter App (Android/Desktop)
      ↓
Local Database (Offline First)
      ↓
Sync Service
      ↓
Django Backend
      ↓
PostgreSQL + MikroTik Routers

2.2 Architecture Style
Hybrid Offline + Cloud
Frontend Responsibilities

local storage

UI

voucher creation

sales

SMS sending

offline work

Backend Responsibilities

central backup

sync

reporting

authentication

MikroTik integration only

3. Technology Stack
Frontend

Flutter

Riverpod/Bloc

Drift/Isar/Hive

Dio

go_router

telephony (SMS)

Package:
com.pritechvior.viornet

Backend

Django

Django REST Framework

PostgreSQL

routeros_api

Celery

4. Functional Requirements
4.1 Authentication Module
Features

login/logout

role-based access

secure sessions

Roles

Super Admin

Marketing

Sales

Technical

Finance

Agent

4.2 Sites Management
Features

create sites

assign routers

assign agents

revenue per site

site statistics

Data

name

GPS

router IP

credentials

4.3 Client Management
Features

add/edit clients

phone numbers

MAC address

purchase history

expiry tracking

SMS reminder

4.4 Voucher Management
Features

generate vouchers

bulk creation

sell offline

track status

assign to agents

expiry control

Voucher Status

unused

sold

active

expired

4.5 Sales Module
Features

sell vouchers (POS)

receipts

daily summary

agent commission

revenue reports

4.6 Finance Module
Features

expenses

profit calculation

reports

export Excel/PDF

4.7 Asset Management
Assets

routers

APs

switches

UPS

cables

Features

assign to site

serial numbers

movement tracking

warranty

condition tracking

4.8 Maintenance Module
Features

report faults

assign technician

repair logs

downtime records

4.9 SMS Module (Android Only)
Important

NO SMS API.

Features

phone SIM SMS

bulk marketing

expiry reminders

message templates

offline sending

SMS logs

4.10 MikroTik Integration

Backend must:

create hotspot users

generate vouchers

disable expired

fetch online users

traffic stats

Flutter must NOT connect directly.

5. Non-Functional Requirements
Performance

works offline

fast loading

< 2s response

Reliability

local DB safe

sync retry

conflict resolution

Security

JWT auth

encrypted passwords

role permissions

Usability

simple UI

desktop dashboard style

mobile friendly

Scalability

support 100+ sites

support 10k+ clients

6. Database Design (Core Entities)
Tables
Users

id

name

role

Sites

id

name

router_ip

Clients

id

phone

site

Vouchers

id

code

status

Sales

id

voucher

amount

Assets

id

serial

status

Maintenance

id

issue

asset

SMSLogs

id

message

status

Each table includes:

createdAt

updatedAt

isSynced

7. Offline Sync Strategy
Steps

When online:

push local unsynced

pull server updates

resolve conflicts (latest wins)

mark synced

Fields

isSynced

lastSyncedAt

8. User Workflows
Agent Selling Voucher
Login
→ generate voucher
→ sell
→ send SMS
→ sync later

Marketing Reminder
Filter expiring clients
→ send bulk SMS

Technician Repair
Report fault
→ assign
→ repair
→ log maintenance

9. UI Structure

Desktop:

Sidebar

Dashboard

Modules

Mobile:

Bottom nav

Drawer

Modules:

Dashboard

Clients

Vouchers

Sales

Finance

Sites

Assets

Maintenance

SMS

Settings

10. Future Enhancements

QR code scanning

Bluetooth printer

RADIUS server

analytics AI

auto device monitoring

cloud dashboard

11. Conclusion

ViorNet will:

✅ digitize operations
✅ reduce losses
✅ improve tracking
✅ increase revenue
✅ support offline environments
✅ scale to many sites

It acts as:

👉 ISP ERP + CRM + Billing + Inventory + Monitoring
