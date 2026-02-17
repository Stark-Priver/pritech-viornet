import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ISP Subscriptions Table (for resellers to track their own ISP payments per site)
class IspSubscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer().references(Sites, #id)();
  TextColumn get providerName => text()();
  TextColumn get paymentControlNumber => text().nullable()();
  TextColumn get registeredName => text().nullable()();
  TextColumn get serviceNumber => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  RealColumn get amount => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Users Table
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get email => text().unique()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text()();
  TextColumn get passwordHash => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Sites Table
class Sites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  TextColumn get gpsCoordinates => text().nullable()();
  TextColumn get routerIp => text().nullable()();
  TextColumn get routerUsername => text().nullable()();
  TextColumn get routerPassword => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Clients Table
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get macAddress => text().nullable()();
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  TextColumn get address => text().nullable()();
  DateTimeColumn get registrationDate => dateTime()();
  DateTimeColumn get lastPurchaseDate => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get smsReminder => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Vouchers Table
// Sales Table
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get receiptNumber => text().unique()();
  IntColumn get voucherId => integer().nullable().references(Vouchers, #id)();
  IntColumn get clientId => integer().nullable().references(Clients, #id)();
  IntColumn get agentId => integer().references(Users, #id)();
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  RealColumn get amount => real()();
  RealColumn get commission => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text()(); // CASH, MOBILE_MONEY, BANK
  TextColumn get notes => text().nullable()();
  DateTimeColumn get saleDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Expenses Table
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get category =>
      text()(); // MAINTENANCE, EQUIPMENT, SALARY, UTILITY, OTHER
  TextColumn get description => text()();
  RealColumn get amount => real()();
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  IntColumn get createdBy => integer().references(Users, #id)();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get receiptNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Assets Table
class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // ROUTER, AP, SWITCH, UPS, CABLE, OTHER
  TextColumn get serialNumber => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  DateTimeColumn get warrantyExpiry => dateTime().nullable()();
  TextColumn get condition => text()(); // NEW, GOOD, FAIR, POOR, DAMAGED
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Maintenance Table
class Maintenance extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get priority => text()(); // LOW, MEDIUM, HIGH, CRITICAL
  TextColumn get status =>
      text()(); // PENDING, IN_PROGRESS, COMPLETED, CANCELLED
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  IntColumn get assetId => integer().nullable().references(Assets, #id)();
  IntColumn get reportedBy => integer().references(Users, #id)();
  IntColumn get assignedTo => integer().nullable().references(Users, #id)();
  DateTimeColumn get reportedDate => dateTime()();
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  RealColumn get cost => real().nullable()();
  TextColumn get resolution => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// SMS Logs Table
class SmsLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get recipient => text()();
  TextColumn get message => text()();
  TextColumn get status => text()(); // PENDING, SENT, FAILED
  TextColumn get type => text()(); // REMINDER, MARKETING, NOTIFICATION
  IntColumn get clientId => integer().nullable().references(Clients, #id)();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// SMS Templates Table
class SmsTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get message => text()();
  TextColumn get type => text()(); // REMINDER, MARKETING, WELCOME, NOTIFICATION
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Packages Table
class Packages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get duration => integer()(); // Duration in days
  RealColumn get price => real()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Roles Table
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// UserRoles Table (Many-to-Many)
class UserRoles extends Table {
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get roleId =>
      integer().references(Roles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get assignedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, roleId};
}

// UserSites Table (Many-to-Many) - Users assigned to specific sites
class UserSites extends Table {
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get siteId =>
      integer().references(Sites, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get assignedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, siteId};
}

// Vouchers Table
class Vouchers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get code => text().unique()();
  IntColumn get packageId => integer().nullable().references(Packages, #id)();
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  RealColumn get price => real().nullable()();
  TextColumn get validity =>
      text().nullable()(); // e.g., "12Hours", "1Day", "1Week"
  TextColumn get speed => text().nullable()(); // e.g., "5Mbps", "10Mbps"
  TextColumn get status => text()(); // AVAILABLE, SOLD, USED, EXPIRED
  DateTimeColumn get soldAt => dateTime().nullable()();
  IntColumn get soldByUserId => integer().nullable().references(Users, #id)();
  // Note: saleId removed to avoid circular reference. Find sales via Sales.voucherId
  TextColumn get qrCodeData => text().nullable()();
  TextColumn get batchId => text().nullable()(); // For bulk uploads
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Commission Settings Table
class CommissionSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get commissionType => text()(); // PERCENTAGE, FIXED_AMOUNT, TIERED
  RealColumn get rate => real()(); // Percentage (0-100) or fixed amount
  RealColumn get minSaleAmount => real().withDefault(const Constant(0.0))();
  RealColumn get maxSaleAmount => real().nullable()();
  TextColumn get applicableTo =>
      text()(); // ALL_AGENTS, SPECIFIC_ROLE, SPECIFIC_USER, SPECIFIC_CLIENT, SPECIFIC_PACKAGE
  IntColumn get roleId => integer().nullable().references(Roles, #id)();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  IntColumn get clientId => integer().nullable().references(Clients, #id)();
  IntColumn get packageId => integer().nullable().references(Packages, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// Commission History Table
class CommissionHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get agentId => integer().references(Users, #id)();
  RealColumn get commissionAmount => real()();
  RealColumn get saleAmount => real()();
  IntColumn get commissionSettingId =>
      integer().nullable().references(CommissionSettings, #id)();
  RealColumn get commissionRate => real().nullable()();
  TextColumn get calculationDetails => text().nullable()(); // JSON string
  TextColumn get status => text().withDefault(
      const Constant('PENDING'))(); // PENDING, APPROVED, PAID, CANCELLED
  IntColumn get approvedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    Users,
    Sites,
    Clients,
    IspSubscriptions,
    Vouchers,
    Sales,
    Expenses,
    Assets,
    Maintenance,
    SmsLogs,
    SmsTemplates,
    Packages,
    Roles,
    UserRoles,
    UserSites,
    CommissionSettings,
    CommissionHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Insert default roles first
        final rolesList = [
          RolesCompanion.insert(
            name: 'SUPER_ADMIN',
            description: 'Full system access with all permissions',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RolesCompanion.insert(
            name: 'MARKETING',
            description: 'Marketing team with client and SMS management',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RolesCompanion.insert(
            name: 'SALES',
            description: 'Sales team with voucher and package management',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RolesCompanion.insert(
            name: 'TECHNICAL',
            description: 'Technical team with site and asset management',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RolesCompanion.insert(
            name: 'FINANCE',
            description: 'Finance team with expense management',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RolesCompanion.insert(
            name: 'AGENT',
            description: 'Agent with limited access',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await batch((batch) {
          batch.insertAll(roles, rolesList);
        });

        // Insert default super admin user
        final adminId = await into(users).insert(
          UsersCompanion.insert(
            name: 'Super Admin',
            email: 'admin@viornet.com',
            phone: const Value('+255000000000'),
            role: 'SUPER_ADMIN',
            passwordHash: 'admin123', // Should be hashed in production
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Assign SUPER_ADMIN role to admin user
        final superAdminRole = await (select(roles)
              ..where((tbl) => tbl.name.equals('SUPER_ADMIN')))
            .getSingle();

        await into(userRoles).insert(
          UserRolesCompanion.insert(
            userId: adminId,
            roleId: superAdminRole.id,
            assignedAt: DateTime.now(),
          ),
        );

        // Insert default SMS templates
        await batch((batch) {
          batch.insertAll(smsTemplates, [
            SmsTemplatesCompanion.insert(
              name: 'Expiry Reminder',
              message:
                  'Dear {name}, your ViorNet subscription expires on {date}. Renew now to continue enjoying uninterrupted service. Thank you!',
              type: 'REMINDER',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            SmsTemplatesCompanion.insert(
              name: 'Welcome Message',
              message:
                  'Welcome to ViorNet! Your voucher code is {code}. Use it to connect to our WiFi network. For support, call {support_phone}.',
              type: 'WELCOME',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            SmsTemplatesCompanion.insert(
              name: 'Marketing Promo',
              message:
                  'ViorNet Special Offer! Get 20% OFF on all monthly packages. Visit our office or call {support_phone} to subscribe today!',
              type: 'MARKETING',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ]);
        });

        // Insert default packages
        await batch((batch) {
          batch.insertAll(packages, [
            PackagesCompanion.insert(
              name: '1 Week',
              duration: 7,
              price: 5000.0,
              description: const Value('Weekly internet access package'),
              isActive: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            PackagesCompanion.insert(
              name: '2 Weeks',
              duration: 14,
              price: 9000.0,
              description: const Value('Bi-weekly internet access package'),
              isActive: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            PackagesCompanion.insert(
              name: '1 Month',
              duration: 30,
              price: 15000.0,
              description: const Value('Monthly internet access package'),
              isActive: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            PackagesCompanion.insert(
              name: '3 Months',
              duration: 90,
              price: 40000.0,
              description: const Value('Quarterly internet access package'),
              isActive: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ]);
        });
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle database upgrades here
        if (from < 2) {
          // Add Packages table for version 2
          await m.createTable(packages);

          // Insert default packages
          await batch((batch) {
            batch.insertAll(packages, [
              PackagesCompanion.insert(
                name: '1 Week',
                duration: 7,
                price: 5000.0,
                description: const Value('Weekly internet access package'),
                isActive: const Value(true),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              PackagesCompanion.insert(
                name: '2 Weeks',
                duration: 14,
                price: 9000.0,
                description: const Value('Bi-weekly internet access package'),
                isActive: const Value(true),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              PackagesCompanion.insert(
                name: '1 Month',
                duration: 30,
                price: 15000.0,
                description: const Value('Monthly internet access package'),
                isActive: const Value(true),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              PackagesCompanion.insert(
                name: '3 Months',
                duration: 90,
                price: 40000.0,
                description: const Value('Quarterly internet access package'),
                isActive: const Value(true),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ]);
          });
        }
        if (from < 3) {
          // Add Roles and UserRoles tables for version 3
          await m.createTable(roles);
          await m.createTable(userRoles);

          // Insert default roles
          final rolesList = [
            RolesCompanion.insert(
              name: 'SUPER_ADMIN',
              description: 'Full system access with all permissions',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            RolesCompanion.insert(
              name: 'MARKETING',
              description: 'Marketing team with client and SMS management',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            RolesCompanion.insert(
              name: 'SALES',
              description: 'Sales team with voucher and package management',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            RolesCompanion.insert(
              name: 'TECHNICAL',
              description: 'Technical team with site and asset management',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            RolesCompanion.insert(
              name: 'FINANCE',
              description: 'Finance team with expense management',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            RolesCompanion.insert(
              name: 'AGENT',
              description: 'Agent with limited access',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          await batch((batch) {
            batch.insertAll(roles, rolesList);
          });

          // Migrate existing users' roles to UserRoles table
          final existingUsers = await select(users).get();
          for (final user in existingUsers) {
            // Find the role ID for the user's current role
            final roleQuery = await (select(roles)
                  ..where((tbl) => tbl.name.equals(user.role)))
                .getSingleOrNull();

            if (roleQuery != null) {
              await into(userRoles).insert(
                UserRolesCompanion.insert(
                  userId: user.id,
                  roleId: roleQuery.id,
                  assignedAt: DateTime.now(),
                ),
              );
            }
          }
        }
        if (from < 4) {
          // Add UserSites table for version 4
          await m.createTable(userSites);
        }
        if (from < 5) {
          // Add Commission tables for version 5
          await m.createTable(commissionSettings);
          await m.createTable(commissionHistory);
        }
        if (from < 6) {
          // Add clientId and packageId columns to commission_settings for version 6
          await m.addColumn(commissionSettings, commissionSettings.clientId);
          await m.addColumn(commissionSettings, commissionSettings.packageId);
        }
        if (from < 7) {
          // Add Vouchers table for version 7
          await m.createTable(vouchers);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'viornet_local.db'));
    return NativeDatabase.createInBackground(file);
  });
}
