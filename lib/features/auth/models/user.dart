class User {
  // Core fields (ALL users have these)
  final int id;
  final String? username;
  final String? phoneNumber;
  final String role; // 'user', 'official', or 'admin'
  final int? countyId;
  final County? county; // Relationship object
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  // Official-specific fields (null for regular users)
  final String? officialName;
  final String? email;
  final String? bio;
  final String? profilePhoto;
  final String? officeAddress;
  final bool? canPost;
  final String? subscriptionStatus; // 'active', 'grace_period', 'expired'
  final DateTime? subscriptionExpiresAt;

  User({
    required this.id,
    this.username,
    this.phoneNumber,
    required this.role,
    this.countyId,
    this.county,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    this.officialName,
    this.email,
    this.bio,
    this.profilePhoto,
    this.officeAddress,
    this.canPost,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
  });

  // Convenience getters
  bool get isOfficial => role == 'official';
  bool get isRegularUser => role == 'user';
  bool get isAdmin => role == 'admin';

  String get displayName => officialName ?? username ?? phoneNumber ?? 'User';
  String get name => officialName ?? username ?? phoneNumber ?? 'User';

  bool get hasActiveSubscription {
    if (!isOfficial) return false;
    return subscriptionStatus == 'active' ||
           (subscriptionStatus == 'grace_period' &&
            subscriptionExpiresAt != null &&
            subscriptionExpiresAt!.isAfter(DateTime.now()));
  }

  bool get canCreatePosts => isOfficial && (canPost ?? false) && hasActiveSubscription;

  // JSON parsing
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      phoneNumber: json['phone_number'],
      role: json['role'],
      countyId: json['county_id'],
      county: json['county'] != null ? County.fromJson(json['county']) : null,
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      lastLoginAt: json['last_login_at'] != null
        ? DateTime.parse(json['last_login_at'])
        : null,

      // Official fields (will be null for regular users)
      officialName: json['official_name'],
      email: json['email'],
      bio: json['bio'],
      profilePhoto: json['profile_photo'],
      officeAddress: json['office_address'],
      canPost: json['can_post'],
      subscriptionStatus: json['subscription_status'],
      subscriptionExpiresAt: json['subscription_expires_at'] != null
        ? DateTime.parse(json['subscription_expires_at'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phone_number': phoneNumber,
      'role': role,
      'county_id': countyId,
      'is_active': isActive,
      // Add official fields only if user is official
      if (isOfficial) ...{
        'official_name': officialName,
        'email': email,
        'bio': bio,
        'profile_photo': profilePhoto,
        'office_address': officeAddress,
      },
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? phoneNumber,
    String? role,
    int? countyId,
    County? county,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? officialName,
    String? email,
    String? bio,
    String? profilePhoto,
    String? officeAddress,
    bool? canPost,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      countyId: countyId ?? this.countyId,
      county: county ?? this.county,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      officialName: officialName ?? this.officialName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      officeAddress: officeAddress ?? this.officeAddress,
      canPost: canPost ?? this.canPost,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
    );
  }
}

// Simple County model for the relationship
class County {
  final int id;
  final String name;
  final String slug;

  County({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory County.fromJson(Map<String, dynamic> json) {
    return County(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
    };
  }
}