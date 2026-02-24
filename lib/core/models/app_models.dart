// ============================================================
// app_models.dart
// Plain Dart models matching Supabase PostgreSQL schema.
// Replaces Drift-generated data classes.
// ============================================================

// ---------------------------------------------------------------------------
// AppUser  (named AppUser to avoid conflict with supabase_flutter's User)
// ---------------------------------------------------------------------------
class AppUser {
  final int id;
  final String? serverId;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String passwordHash;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    this.serverId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.passwordHash,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        passwordHash: json['password_hash'] as String,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'server_id': serverId,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'password_hash': passwordHash,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  AppUser copyWith({
    int? id,
    String? serverId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? passwordHash,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        passwordHash: passwordHash ?? this.passwordHash,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Site
// ---------------------------------------------------------------------------
class Site {
  final int id;
  final String? serverId;
  final String name;
  final String? location;
  final String? gpsCoordinates;
  final String? routerIp;
  final String? routerUsername;
  final String? routerPassword;
  final String? contactPerson;
  final String? contactPhone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Site({
    required this.id,
    this.serverId,
    required this.name,
    this.location,
    this.gpsCoordinates,
    this.routerIp,
    this.routerUsername,
    this.routerPassword,
    this.contactPerson,
    this.contactPhone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        location: json['location'] as String?,
        gpsCoordinates: json['gps_coordinates'] as String?,
        routerIp: json['router_ip'] as String?,
        routerUsername: json['router_username'] as String?,
        routerPassword: json['router_password'] as String?,
        contactPerson: json['contact_person'] as String?,
        contactPhone: json['contact_phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'gps_coordinates': gpsCoordinates,
        'router_ip': routerIp,
        'router_username': routerUsername,
        'router_password': routerPassword,
        'contact_person': contactPerson,
        'contact_phone': contactPhone,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Site copyWith({
    int? id,
    String? serverId,
    String? name,
    String? location,
    String? gpsCoordinates,
    String? routerIp,
    String? routerUsername,
    String? routerPassword,
    String? contactPerson,
    String? contactPhone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Site(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        location: location ?? this.location,
        gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
        routerIp: routerIp ?? this.routerIp,
        routerUsername: routerUsername ?? this.routerUsername,
        routerPassword: routerPassword ?? this.routerPassword,
        contactPerson: contactPerson ?? this.contactPerson,
        contactPhone: contactPhone ?? this.contactPhone,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------
class Client {
  final int id;
  final String? serverId;
  final String name;
  final String phone;
  final String? email;
  final String? macAddress;
  final int? siteId;
  final String? address;
  final DateTime registrationDate;
  final DateTime? lastPurchaseDate;
  final DateTime? expiryDate;
  final bool isActive;
  final bool smsReminder;
  final String? notes;
  final int? registeredBy; // user who registered this client
  final int? assignedTo; // user the client was transferred/assigned to
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    this.serverId,
    required this.name,
    required this.phone,
    this.email,
    this.macAddress,
    this.siteId,
    this.address,
    required this.registrationDate,
    this.lastPurchaseDate,
    this.expiryDate,
    required this.isActive,
    required this.smsReminder,
    this.notes,
    this.registeredBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        macAddress: json['mac_address'] as String?,
        siteId: json['site_id'] as int?,
        address: json['address'] as String?,
        registrationDate: DateTime.parse(json['registration_date'] as String),
        lastPurchaseDate: json['last_purchase_date'] != null
            ? DateTime.parse(json['last_purchase_date'] as String)
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'] as String)
            : null,
        isActive: json['is_active'] as bool? ?? true,
        smsReminder: json['sms_reminder'] as bool? ?? true,
        notes: json['notes'] as String?,
        registeredBy: json['registered_by'] as int?,
        assignedTo: json['assigned_to'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'mac_address': macAddress,
        'site_id': siteId,
        'address': address,
        'registration_date': registrationDate.toIso8601String(),
        'last_purchase_date': lastPurchaseDate?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'is_active': isActive,
        'sms_reminder': smsReminder,
        'notes': notes,
        'registered_by': registeredBy,
        'assigned_to': assignedTo,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Client copyWith({
    int? id,
    String? serverId,
    String? name,
    String? phone,
    String? email,
    String? macAddress,
    int? siteId,
    String? address,
    DateTime? registrationDate,
    DateTime? lastPurchaseDate,
    DateTime? expiryDate,
    bool? isActive,
    bool? smsReminder,
    String? notes,
    int? registeredBy,
    int? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Client(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        macAddress: macAddress ?? this.macAddress,
        siteId: siteId ?? this.siteId,
        address: address ?? this.address,
        registrationDate: registrationDate ?? this.registrationDate,
        lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
        expiryDate: expiryDate ?? this.expiryDate,
        isActive: isActive ?? this.isActive,
        smsReminder: smsReminder ?? this.smsReminder,
        notes: notes ?? this.notes,
        registeredBy: registeredBy ?? this.registeredBy,
        assignedTo: assignedTo ?? this.assignedTo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Package
// ---------------------------------------------------------------------------
class Package {
  final int id;
  final String? serverId;
  final String name;
  final int duration; // days
  final double price;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Package({
    required this.id,
    this.serverId,
    required this.name,
    required this.duration,
    required this.price,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Package.fromJson(Map<String, dynamic> json) => Package(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        duration: json['duration'] as int,
        price: (json['price'] as num).toDouble(),
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'duration': duration,
        'price': price,
        'description': description,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Package copyWith({
    int? id,
    String? serverId,
    String? name,
    int? duration,
    double? price,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Package(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        duration: duration ?? this.duration,
        price: price ?? this.price,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Voucher
// ---------------------------------------------------------------------------
class Voucher {
  final int id;
  final String? serverId;
  final String code;
  final int? packageId;
  final int? siteId;
  final double? price;
  final String? validity;
  final String? speed;
  final String status; // AVAILABLE, SOLD, USED, EXPIRED
  final DateTime? soldAt;
  final int? soldByUserId;
  final String? qrCodeData;
  final String? batchId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Voucher({
    required this.id,
    this.serverId,
    required this.code,
    this.packageId,
    this.siteId,
    this.price,
    this.validity,
    this.speed,
    required this.status,
    this.soldAt,
    this.soldByUserId,
    this.qrCodeData,
    this.batchId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        code: json['code'] as String,
        packageId: json['package_id'] as int?,
        siteId: json['site_id'] as int?,
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        validity: json['validity'] as String?,
        speed: json['speed'] as String?,
        status: json['status'] as String? ?? 'AVAILABLE',
        soldAt: json['sold_at'] != null
            ? DateTime.parse(json['sold_at'] as String)
            : null,
        soldByUserId: json['sold_by_user_id'] as int?,
        qrCodeData: json['qr_code_data'] as String?,
        batchId: json['batch_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'package_id': packageId,
        'site_id': siteId,
        'price': price,
        'validity': validity,
        'speed': speed,
        'status': status,
        'sold_at': soldAt?.toIso8601String(),
        'sold_by_user_id': soldByUserId,
        'qr_code_data': qrCodeData,
        'batch_id': batchId,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Voucher copyWith({
    int? id,
    String? serverId,
    String? code,
    int? packageId,
    int? siteId,
    double? price,
    String? validity,
    String? speed,
    String? status,
    DateTime? soldAt,
    int? soldByUserId,
    String? qrCodeData,
    String? batchId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Voucher(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        code: code ?? this.code,
        packageId: packageId ?? this.packageId,
        siteId: siteId ?? this.siteId,
        price: price ?? this.price,
        validity: validity ?? this.validity,
        speed: speed ?? this.speed,
        status: status ?? this.status,
        soldAt: soldAt ?? this.soldAt,
        soldByUserId: soldByUserId ?? this.soldByUserId,
        qrCodeData: qrCodeData ?? this.qrCodeData,
        batchId: batchId ?? this.batchId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Sale
// ---------------------------------------------------------------------------
class Sale {
  final int id;
  final String? serverId;
  final String receiptNumber;
  final int? voucherId;
  final int? clientId;
  final int agentId;
  final int? siteId;
  final double amount;
  final double commission;
  final String paymentMethod;
  final String? notes;
  final DateTime saleDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    required this.id,
    this.serverId,
    required this.receiptNumber,
    this.voucherId,
    this.clientId,
    required this.agentId,
    this.siteId,
    required this.amount,
    required this.commission,
    required this.paymentMethod,
    this.notes,
    required this.saleDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        receiptNumber: json['receipt_number'] as String,
        voucherId: json['voucher_id'] as int?,
        clientId: json['client_id'] as int?,
        agentId: json['agent_id'] as int,
        siteId: json['site_id'] as int?,
        amount: (json['amount'] as num).toDouble(),
        commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: json['payment_method'] as String,
        notes: json['notes'] as String?,
        saleDate: DateTime.parse(json['sale_date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'receipt_number': receiptNumber,
        'voucher_id': voucherId,
        'client_id': clientId,
        'agent_id': agentId,
        'site_id': siteId,
        'amount': amount,
        'commission': commission,
        'payment_method': paymentMethod,
        'notes': notes,
        'sale_date': saleDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  Sale copyWith({
    int? id,
    String? serverId,
    String? receiptNumber,
    int? voucherId,
    int? clientId,
    int? agentId,
    int? siteId,
    double? amount,
    double? commission,
    String? paymentMethod,
    String? notes,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Sale(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        voucherId: voucherId ?? this.voucherId,
        clientId: clientId ?? this.clientId,
        agentId: agentId ?? this.agentId,
        siteId: siteId ?? this.siteId,
        amount: amount ?? this.amount,
        commission: commission ?? this.commission,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        saleDate: saleDate ?? this.saleDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Expense
// ---------------------------------------------------------------------------
class Expense {
  final int id;
  final String? serverId;
  final String category;
  final String description;
  final double amount;
  final int? siteId;
  final int createdBy;
  final DateTime expenseDate;
  final String? receiptNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    this.serverId,
    required this.category,
    required this.description,
    required this.amount,
    this.siteId,
    required this.createdBy,
    required this.expenseDate,
    this.receiptNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        category: json['category'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        siteId: json['site_id'] as int?,
        createdBy: json['created_by'] as int,
        expenseDate: DateTime.parse(json['expense_date'] as String),
        receiptNumber: json['receipt_number'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'amount': amount,
        'site_id': siteId,
        'created_by': createdBy,
        'expense_date': expenseDate.toIso8601String(),
        'receipt_number': receiptNumber,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Expense copyWith({
    int? id,
    String? serverId,
    String? category,
    String? description,
    double? amount,
    int? siteId,
    int? createdBy,
    DateTime? expenseDate,
    String? receiptNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        category: category ?? this.category,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        siteId: siteId ?? this.siteId,
        createdBy: createdBy ?? this.createdBy,
        expenseDate: expenseDate ?? this.expenseDate,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Asset
// ---------------------------------------------------------------------------
class Asset {
  final int id;
  final String? serverId;
  final String name;
  final String type;
  final String? serialNumber;
  final String? model;
  final String? manufacturer;
  final int? siteId;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final DateTime? warrantyExpiry;
  final String condition;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Asset({
    required this.id,
    this.serverId,
    required this.name,
    required this.type,
    this.serialNumber,
    this.model,
    this.manufacturer,
    this.siteId,
    this.purchaseDate,
    this.purchasePrice,
    this.warrantyExpiry,
    required this.condition,
    this.location,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        type: json['type'] as String,
        serialNumber: json['serial_number'] as String?,
        model: json['model'] as String?,
        manufacturer: json['manufacturer'] as String?,
        siteId: json['site_id'] as int?,
        purchaseDate: json['purchase_date'] != null
            ? DateTime.parse(json['purchase_date'] as String)
            : null,
        purchasePrice: json['purchase_price'] != null
            ? (json['purchase_price'] as num).toDouble()
            : null,
        warrantyExpiry: json['warranty_expiry'] != null
            ? DateTime.parse(json['warranty_expiry'] as String)
            : null,
        condition: json['condition'] as String,
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'serial_number': serialNumber,
        'model': model,
        'manufacturer': manufacturer,
        'site_id': siteId,
        'purchase_date': purchaseDate?.toIso8601String(),
        'purchase_price': purchasePrice,
        'warranty_expiry': warrantyExpiry?.toIso8601String(),
        'condition': condition,
        'location': location,
        'notes': notes,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Asset copyWith({
    int? id,
    String? serverId,
    String? name,
    String? type,
    String? serialNumber,
    String? model,
    String? manufacturer,
    int? siteId,
    DateTime? purchaseDate,
    double? purchasePrice,
    DateTime? warrantyExpiry,
    String? condition,
    String? location,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Asset(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        type: type ?? this.type,
        serialNumber: serialNumber ?? this.serialNumber,
        model: model ?? this.model,
        manufacturer: manufacturer ?? this.manufacturer,
        siteId: siteId ?? this.siteId,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
        condition: condition ?? this.condition,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// MaintenanceRecord  (was MaintenanceData in Drift)
// ---------------------------------------------------------------------------
class MaintenanceRecord {
  final int id;
  final String? serverId;
  final String title;
  final String description;
  final String priority; // LOW, MEDIUM, HIGH, CRITICAL
  final String status; // PENDING, IN_PROGRESS, COMPLETED, CANCELLED
  final int? siteId;
  final int? assetId;
  final int reportedBy;
  final int? assignedTo;
  final DateTime reportedDate;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final double? cost;
  final String? resolution;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaintenanceRecord({
    required this.id,
    this.serverId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.siteId,
    this.assetId,
    required this.reportedBy,
    this.assignedTo,
    required this.reportedDate,
    this.scheduledDate,
    this.completedDate,
    this.cost,
    this.resolution,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecord(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String,
        priority: json['priority'] as String,
        status: json['status'] as String,
        siteId: json['site_id'] as int?,
        assetId: json['asset_id'] as int?,
        reportedBy: json['reported_by'] as int,
        assignedTo: json['assigned_to'] as int?,
        reportedDate: DateTime.parse(json['reported_date'] as String),
        scheduledDate: json['scheduled_date'] != null
            ? DateTime.parse(json['scheduled_date'] as String)
            : null,
        completedDate: json['completed_date'] != null
            ? DateTime.parse(json['completed_date'] as String)
            : null,
        cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
        resolution: json['resolution'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'site_id': siteId,
        'asset_id': assetId,
        'reported_by': reportedBy,
        'assigned_to': assignedTo,
        'reported_date': reportedDate.toIso8601String(),
        'scheduled_date': scheduledDate?.toIso8601String(),
        'completed_date': completedDate?.toIso8601String(),
        'cost': cost,
        'resolution': resolution,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  MaintenanceRecord copyWith({
    int? id,
    String? serverId,
    String? title,
    String? description,
    String? priority,
    String? status,
    int? siteId,
    int? assetId,
    int? reportedBy,
    int? assignedTo,
    DateTime? reportedDate,
    DateTime? scheduledDate,
    DateTime? completedDate,
    double? cost,
    String? resolution,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MaintenanceRecord(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        siteId: siteId ?? this.siteId,
        assetId: assetId ?? this.assetId,
        reportedBy: reportedBy ?? this.reportedBy,
        assignedTo: assignedTo ?? this.assignedTo,
        reportedDate: reportedDate ?? this.reportedDate,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        completedDate: completedDate ?? this.completedDate,
        cost: cost ?? this.cost,
        resolution: resolution ?? this.resolution,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// SmsLog
// ---------------------------------------------------------------------------
class SmsLog {
  final int id;
  final String? serverId;
  final String recipient;
  final String message;
  final String status; // PENDING, SENT, FAILED
  final String type; // REMINDER, MARKETING, NOTIFICATION
  final int? clientId;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmsLog({
    required this.id,
    this.serverId,
    required this.recipient,
    required this.message,
    required this.status,
    required this.type,
    this.clientId,
    this.scheduledAt,
    this.sentAt,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SmsLog.fromJson(Map<String, dynamic> json) => SmsLog(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        recipient: json['recipient'] as String,
        message: json['message'] as String,
        status: json['status'] as String,
        type: json['type'] as String,
        clientId: json['client_id'] as int?,
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.parse(json['scheduled_at'] as String)
            : null,
        sentAt: json['sent_at'] != null
            ? DateTime.parse(json['sent_at'] as String)
            : null,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'recipient': recipient,
        'message': message,
        'status': status,
        'type': type,
        'client_id': clientId,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
        'error_message': errorMessage,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// SmsTemplate
// ---------------------------------------------------------------------------
class SmsTemplate {
  final int id;
  final String? serverId;
  final String name;
  final String message;
  final String type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmsTemplate({
    required this.id,
    this.serverId,
    required this.name,
    required this.message,
    required this.type,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SmsTemplate.fromJson(Map<String, dynamic> json) => SmsTemplate(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        name: json['name'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'message': message,
        'type': type,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

  SmsTemplate copyWith({
    int? id,
    String? serverId,
    String? name,
    String? message,
    String? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SmsTemplate(
        id: id ?? this.id,
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        message: message ?? this.message,
        type: type ?? this.type,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Role
// ---------------------------------------------------------------------------
class Role {
  final int id;
  final String name;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// UserRole  (join table)
// ---------------------------------------------------------------------------
class UserRole {
  final int userId;
  final int roleId;
  final DateTime assignedAt;

  const UserRole({
    required this.userId,
    required this.roleId,
    required this.assignedAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
        userId: json['user_id'] as int,
        roleId: json['role_id'] as int,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// UserSite  (join table)
// ---------------------------------------------------------------------------
class UserSite {
  final int userId;
  final int siteId;
  final DateTime assignedAt;

  const UserSite({
    required this.userId,
    required this.siteId,
    required this.assignedAt,
  });

  factory UserSite.fromJson(Map<String, dynamic> json) => UserSite(
        userId: json['user_id'] as int,
        siteId: json['site_id'] as int,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// CommissionSetting
// ---------------------------------------------------------------------------
class CommissionSetting {
  final int id;
  final String name;
  final String? description;
  final String commissionType; // PERCENTAGE, FIXED_AMOUNT, TIERED
  final double rate;
  final double minSaleAmount;
  final double? maxSaleAmount;
  final String applicableTo;
  final int? roleId;
  final int? userId;
  final int? clientId;
  final int? packageId;
  final bool isActive;
  final int priority;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommissionSetting({
    required this.id,
    required this.name,
    this.description,
    required this.commissionType,
    required this.rate,
    required this.minSaleAmount,
    this.maxSaleAmount,
    required this.applicableTo,
    this.roleId,
    this.userId,
    this.clientId,
    this.packageId,
    required this.isActive,
    required this.priority,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommissionSetting.fromJson(Map<String, dynamic> json) =>
      CommissionSetting(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        commissionType: json['commission_type'] as String,
        rate: (json['rate'] as num).toDouble(),
        minSaleAmount: (json['min_sale_amount'] as num?)?.toDouble() ?? 0.0,
        maxSaleAmount: json['max_sale_amount'] != null
            ? (json['max_sale_amount'] as num).toDouble()
            : null,
        applicableTo: json['applicable_to'] as String,
        roleId: json['role_id'] as int?,
        userId: json['user_id'] as int?,
        clientId: json['client_id'] as int?,
        packageId: json['package_id'] as int?,
        isActive: json['is_active'] as bool? ?? true,
        priority: json['priority'] as int? ?? 0,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'commission_type': commissionType,
        'rate': rate,
        'min_sale_amount': minSaleAmount,
        'max_sale_amount': maxSaleAmount,
        'applicable_to': applicableTo,
        'role_id': roleId,
        'user_id': userId,
        'client_id': clientId,
        'package_id': packageId,
        'is_active': isActive,
        'priority': priority,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  CommissionSetting copyWith({
    int? id,
    String? name,
    String? description,
    String? commissionType,
    double? rate,
    double? minSaleAmount,
    double? maxSaleAmount,
    String? applicableTo,
    int? roleId,
    int? userId,
    int? clientId,
    int? packageId,
    bool? isActive,
    int? priority,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CommissionSetting(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        commissionType: commissionType ?? this.commissionType,
        rate: rate ?? this.rate,
        minSaleAmount: minSaleAmount ?? this.minSaleAmount,
        maxSaleAmount: maxSaleAmount ?? this.maxSaleAmount,
        applicableTo: applicableTo ?? this.applicableTo,
        roleId: roleId ?? this.roleId,
        userId: userId ?? this.userId,
        clientId: clientId ?? this.clientId,
        packageId: packageId ?? this.packageId,
        isActive: isActive ?? this.isActive,
        priority: priority ?? this.priority,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------------------------
// CommissionHistory
// ---------------------------------------------------------------------------
class CommissionHistory {
  final int id;
  final String? serverId;
  final int saleId;
  final int agentId;
  final double commissionAmount;
  final double saleAmount;
  final int? commissionSettingId;
  final double? commissionRate;
  final String? calculationDetails;
  final String status; // PENDING, APPROVED, PAID, CANCELLED
  final int? approvedBy;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommissionHistory({
    required this.id,
    this.serverId,
    required this.saleId,
    required this.agentId,
    required this.commissionAmount,
    required this.saleAmount,
    this.commissionSettingId,
    this.commissionRate,
    this.calculationDetails,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.paidAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommissionHistory.fromJson(Map<String, dynamic> json) =>
      CommissionHistory(
        id: json['id'] as int,
        serverId: json['server_id'] as String?,
        saleId: json['sale_id'] as int,
        agentId: json['agent_id'] as int,
        commissionAmount: (json['commission_amount'] as num).toDouble(),
        saleAmount: (json['sale_amount'] as num).toDouble(),
        commissionSettingId: json['commission_setting_id'] as int?,
        commissionRate: json['commission_rate'] != null
            ? (json['commission_rate'] as num).toDouble()
            : null,
        calculationDetails: json['calculation_details'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        approvedBy: json['approved_by'] as int?,
        approvedAt: json['approved_at'] != null
            ? DateTime.parse(json['approved_at'] as String)
            : null,
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'] as String)
            : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'sale_id': saleId,
        'agent_id': agentId,
        'commission_amount': commissionAmount,
        'sale_amount': saleAmount,
        'commission_setting_id': commissionSettingId,
        'commission_rate': commissionRate,
        'calculation_details': calculationDetails,
        'status': status,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// IspSubscription
// ---------------------------------------------------------------------------
class IspSubscription {
  final int id;
  final int siteId;
  final String providerName;
  final String? paymentControlNumber;
  final String? registeredName;
  final String? serviceNumber;
  final DateTime paidAt;
  final DateTime endsAt;
  final double? amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IspSubscription({
    required this.id,
    required this.siteId,
    required this.providerName,
    this.paymentControlNumber,
    this.registeredName,
    this.serviceNumber,
    required this.paidAt,
    required this.endsAt,
    this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IspSubscription.fromJson(Map<String, dynamic> json) =>
      IspSubscription(
        id: json['id'] as int,
        siteId: json['site_id'] as int,
        providerName: json['provider_name'] as String,
        paymentControlNumber: json['payment_control_number'] as String?,
        registeredName: json['registered_name'] as String?,
        serviceNumber: json['service_number'] as String?,
        paidAt: DateTime.parse(json['paid_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        amount:
            json['amount'] != null ? (json['amount'] as num).toDouble() : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'site_id': siteId,
        'provider_name': providerName,
        'payment_control_number': paymentControlNumber,
        'registered_name': registeredName,
        'service_number': serviceNumber,
        'paid_at': paidAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'amount': amount,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  IspSubscription copyWith({
    int? id,
    int? siteId,
    String? providerName,
    String? paymentControlNumber,
    String? registeredName,
    String? serviceNumber,
    DateTime? paidAt,
    DateTime? endsAt,
    double? amount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      IspSubscription(
        id: id ?? this.id,
        siteId: siteId ?? this.siteId,
        providerName: providerName ?? this.providerName,
        paymentControlNumber: paymentControlNumber ?? this.paymentControlNumber,
        registeredName: registeredName ?? this.registeredName,
        serviceNumber: serviceNumber ?? this.serviceNumber,
        paidAt: paidAt ?? this.paidAt,
        endsAt: endsAt ?? this.endsAt,
        amount: amount ?? this.amount,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ============================================================
// INVESTOR
// ============================================================

class Investor {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final double investedAmount;
  final DateTime investDate;

  /// Percentage of net profit returned to this investor per period.
  final double roiPercentage;

  /// MONTHLY | QUARTERLY | ANNUALLY
  final String returnPeriod;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investor({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.investedAmount,
    required this.investDate,
    required this.roiPercentage,
    required this.returnPeriod,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Investor.fromJson(Map<String, dynamic> json) => Investor(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        investedAmount: (json['invested_amount'] as num?)?.toDouble() ?? 0.0,
        investDate: DateTime.parse(json['invest_date'] as String),
        roiPercentage: (json['roi_percentage'] as num?)?.toDouble() ?? 0.0,
        returnPeriod: json['return_period'] as String? ?? 'MONTHLY',
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(
            json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'invested_amount': investedAmount,
        'invest_date': investDate.toIso8601String().split('T').first,
        'roi_percentage': roiPercentage,
        'return_period': returnPeriod,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Investor copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    double? investedAmount,
    DateTime? investDate,
    double? roiPercentage,
    String? returnPeriod,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Investor(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        investedAmount: investedAmount ?? this.investedAmount,
        investDate: investDate ?? this.investDate,
        roiPercentage: roiPercentage ?? this.roiPercentage,
        returnPeriod: returnPeriod ?? this.returnPeriod,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Calculates investor return amount for a given net profit.
  double calculateReturn(double netProfit) => netProfit * (roiPercentage / 100);
}

// ---------------------------------------------------------------------------
// VoucherQuotaSetting
// ---------------------------------------------------------------------------
class VoucherQuotaSetting {
  final int id;
  final int? siteId; // null = global (all sites)
  final int? packageId; // null = all packages for this site
  final int quotaLimit;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VoucherQuotaSetting({
    required this.id,
    this.siteId,
    this.packageId,
    required this.quotaLimit,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoucherQuotaSetting.fromJson(Map<String, dynamic> j) =>
      VoucherQuotaSetting(
        id: j['id'] as int,
        siteId: j['site_id'] as int?,
        packageId: j['package_id'] as int?,
        quotaLimit: j['quota_limit'] as int? ?? 10,
        isEnabled: j['is_enabled'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  VoucherQuotaSetting copyWith({
    int? quotaLimit,
    bool? isEnabled,
  }) =>
      VoucherQuotaSetting(
        id: id,
        siteId: siteId,
        packageId: packageId,
        quotaLimit: quotaLimit ?? this.quotaLimit,
        isEnabled: isEnabled ?? this.isEnabled,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// SalesRemittance
// ---------------------------------------------------------------------------
class SalesRemittance {
  final int id;
  final String serverId;
  final int agentId;
  final int? siteId;
  final double amount;
  final String? notes;
  final String status; // PENDING | CONFIRMED | REJECTED
  final DateTime submittedAt;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalesRemittance({
    required this.id,
    required this.serverId,
    required this.agentId,
    this.siteId,
    required this.amount,
    this.notes,
    required this.status,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesRemittance.fromJson(Map<String, dynamic> j) => SalesRemittance(
        id: j['id'] as int,
        serverId: j['server_id'] as String? ?? '',
        agentId: j['agent_id'] as int,
        siteId: j['site_id'] as int?,
        amount: (j['amount'] as num).toDouble(),
        notes: j['notes'] as String?,
        status: j['status'] as String? ?? 'PENDING',
        submittedAt: DateTime.parse(j['submitted_at'] as String),
        reviewedBy: j['reviewed_by'] as int?,
        reviewedAt: j['reviewed_at'] != null
            ? DateTime.parse(j['reviewed_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
