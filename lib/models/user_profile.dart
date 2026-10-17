/// Signed-in Supabase user plus their `profiles` row.
class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName = '',
    this.phone = '',
    this.city = '',
    this.avatarUrl = '',
    this.isVerified = false,
  });

  final String id;
  final String fullName;
  final String phone;
  final String city;
  final String avatarUrl;
  final bool isVerified;

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? city,
    String? avatarUrl,
    bool? isVerified,
  }) => UserProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isVerified: isVerified ?? this.isVerified,
  );

  String get displayName =>
      fullName.trim().isEmpty ? 'Apni Gari User' : fullName.trim();

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    id: '${row['id']}',
    fullName: '${row['full_name'] ?? ''}',
    phone: '${row['phone'] ?? ''}',
    city: '${row['city'] ?? ''}',
    avatarUrl: '${row['avatar_url'] ?? ''}',
    isVerified: row['is_verified'] == true,
  );
}
