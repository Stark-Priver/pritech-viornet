import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/database/database.dart';
import 'core/services/supabase_postgres_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase PostgreSQL Sync (record-level sync, no auth)
  await SupabaseSyncService.initialize(
    supabaseUrl: 'https://bylovbbaatsigcfsdspn.supabase.co',
    supabaseServiceKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5bG92YmJhYXRzaWdjZnNkc3BuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDM1OTg3NSwiZXhwIjoyMDg1OTM1ODc1fQ.FGkddKMLiXPQOjQRBCfY2BoG-wTByjfJ2oKnlxv-JZQ',
  );

  // Initialize API Service
  ApiService().initialize();

  // Initialize database with default admin user
  await _initializeDatabase();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Initialize database with default admin user
Future<void> _initializeDatabase() async {
  final database = AppDatabase();

  // Check if admin user exists
  final adminExists = await (database.select(database.users)
        ..where((tbl) => tbl.email.equals('admin@viornet.com')))
      .getSingleOrNull();

  if (adminExists == null) {
    // Create default admin user
    // Username: admin@viornet.com
    // Password: admin123
    final passwordHash = sha256.convert(utf8.encode('admin123')).toString();

    await database.into(database.users).insert(
          UsersCompanion.insert(
            name: 'System Administrator',
            email: 'admin@viornet.com',
            phone: const drift.Value('0000000000'),
            role: 'SUPER_ADMIN',
            passwordHash: passwordHash,
            isActive: const drift.Value(true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    debugPrint('✅ Default admin user created: admin@viornet.com / admin123');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'ViorNet - ISP Management System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }
}
