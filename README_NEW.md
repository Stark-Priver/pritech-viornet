# ViorNet - WiFi Reseller & ISP Management System

A comprehensive offline-first WiFi reseller and ISP management system built with Flutter and designed to work on Android and Windows Desktop platforms.

## Features

### Core Modules
- **Authentication** - Secure login with role-based access control
- **Dashboard** - Real-time analytics and statistics
- **Client Management** - Track customers, expiry dates, and purchase history
- **Voucher Management** - Generate, sell, and track internet vouchers
- **Sales/POS** - Point of sale system with receipt generation
- **Site Management** - Manage multiple WiFi locations
- **Asset Management** - Track routers, APs, and other equipment
- **Maintenance** - Report and track repairs and issues
- **Finance** - Expenses, revenue tracking, and reporting
- **SMS Module** - Send reminders and marketing messages (Android only)
- **Sync Service** - Automatic offline-first data synchronization

### Key Features
- ✅ Offline-first architecture
- ✅ Real-time data synchronization
- ✅ Role-based permissions (Super Admin, Marketing, Sales, Technical, Finance, Agent)
- ✅ SMS notifications using phone SIM (Android)
- ✅ Professional dashboard with charts and analytics
- ✅ Export reports to PDF and Excel
- ✅ Multi-site support
- ✅ Responsive design for desktop and mobile

## Technology Stack

### Frontend
- **Flutter** - Cross-platform UI framework
- **Riverpod** - State management
- **Drift** - Local SQLite database
- **Go Router** - Navigation
- **FL Chart** - Charts and graphs
- **Dio** - HTTP client

### Packages
- `flutter_riverpod` - State management
- `drift` - Local database
- `go_router` - Routing
- `dio` - HTTP client
- `telephony` - SMS (Android)
- `pdf` & `printing` - PDF generation
- `excel` - Excel export
- `fl_chart` - Charts
- `google_fonts` - Typography
- And many more...

## Getting Started

### Prerequisites
- Flutter SDK 3.5.4 or higher
- Dart SDK
- Android Studio / VS Code
- Android SDK (for Android builds)
- Windows SDK (for Windows builds)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/pritechvior/viornet.git
cd viornet
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run code generation:
```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
# For development
flutter run

# For Android
flutter run -d android

# For Windows
flutter run -d windows
```

## Project Structure

```
lib/
├── core/
│   ├── constants/      # App constants
│   ├── database/       # Drift database
│   ├── providers/      # Riverpod providers
│   ├── router/         # Go Router configuration
│   ├── services/       # API, SMS, Sync services
│   └── theme/          # App theming
├── features/
│   ├── auth/           # Authentication
│   ├── assets/         # Asset management
│   ├── clients/        # Client management
│   ├── dashboard/      # Dashboard
│   ├── finance/        # Finance & reporting
│   ├── maintenance/    # Maintenance tracking
│   ├── sales/          # Sales & POS
│   ├── settings/       # Settings
│   ├── sites/          # Site management
│   ├── sms/            # SMS management
│   └── vouchers/       # Voucher management
└── main.dart           # App entry point
```

## Default Credentials

**Email:** admin@viornet.com  
**Password:** admin123

## User Roles

1. **Super Admin** - Full system access
2. **Marketing** - Marketing campaigns and SMS
3. **Sales** - Voucher sales and POS
4. **Technical** - Asset and maintenance management
5. **Finance** - Financial reports and expenses
6. **Agent** - Basic sales operations

## Database Schema

The app uses Drift (SQLite) for local storage with the following main tables:
- Users
- Sites
- Clients
- Vouchers
- Sales
- Expenses
- Assets
- Maintenance
- SMS Logs
- SMS Templates

## Offline-First Architecture

ViorNet is designed to work offline by default:
1. All operations work locally first
2. Data is automatically synced when online
3. Conflict resolution (latest wins)
4. Retry mechanism for failed syncs

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### Windows
```bash
flutter build windows --release
```

## API Integration

The backend API should implement the following endpoints:
- `/auth/login` - Authentication
- `/auth/refresh` - Token refresh
- `/sync/pull` - Pull server updates
- `/sync/push` - Push local changes
- CRUD endpoints for all entities

## Contributing

This is a proprietary project by Pritech Vior Softech.

## License

Copyright © 2026 Pritech Vior Softech. All rights reserved.

## Author

**Privertus Cosmas**  
Pritech Vior Softech

## Support

For support, contact: support@pritechvior.com

## Roadmap

- [ ] QR code voucher generation
- [ ] Bluetooth printer support
- [ ] RADIUS server integration
- [ ] AI-powered analytics
- [ ] Cloud dashboard
- [ ] Mobile app for agents
- [ ] WhatsApp integration
- [ ] Payment gateway integration
