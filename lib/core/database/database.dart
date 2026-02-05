import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

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
class Vouchers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get code => text().unique()();
  TextColumn get username => text().nullable()();
  TextColumn get password => text().nullable()();
  IntColumn get duration => integer()(); // days
  RealColumn get price => real()();
  TextColumn get status => text()(); // UNUSED, SOLD, ACTIVE, EXPIRED
  IntColumn get siteId => integer().nullable().references(Sites, #id)();
  IntColumn get agentId => integer().nullable().references(Users, #id)();
  IntColumn get clientId => integer().nullable().references(Clients, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get soldAt => dateTime().nullable()();
  DateTimeColumn get activatedAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

// Sales Table
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get receiptNumber => text().unique()();
  IntColumn get voucherId => integer().references(Vouchers, #id)();
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

@DriftDatabase(
  tables: [
    Users,
    Sites,
    Clients,
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

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
