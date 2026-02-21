import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/services/supabase_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (online-only mode – no local SQLite)
  await SupabaseDataService.initialize(
    supabaseUrl: 'https://bylovbbaatsigcfsdspn.supabase.co',
    supabaseServiceKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5bG92YmJhYXRzaWdjZnNkc3BuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDM1OTg3NSwiZXhwIjoyMDg1OTM1ODc1fQ.FGkddKMLiXPQOjQRBCfY2BoG-wTByjfJ2oKnlxv-JZQ',
  );

  // Initialize API Service
  ApiService().initialize();

  // Ensure a default admin user exists in Supabase
  await _ensureAdminExists();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Creates the default admin account if it doesn't already exist.
Future<void> _ensureAdminExists() async {
  try {
    final svc = SupabaseDataService();
    final existing = await svc.getUserByEmail('admin@viornet.com');
    if (existing == null) {
      final passwordHash = sha256.convert(utf8.encode('admin123')).toString();
      await svc.createUser(
        name: 'System Administrator',
        email: 'admin@viornet.com',
        passwordHash: passwordHash,
        role: 'SUPER_ADMIN',
        phone: '0000000000',
      );
      debugPrint('✅ Default admin user created: admin@viornet.com / admin123');
    }
  } catch (e) {
    debugPrint('⚠️  Could not seed admin user: $e');
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
