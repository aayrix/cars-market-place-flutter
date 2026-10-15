/// Signed-in Supabase user plus their `profiles` row.
class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName = '',
    this.phone = '',
    this.city = '',
    this.avatarUrl = '',
  });

  final String id;
  final String fullName;
  final String phone;
  final String city;
  final String avatarUrl;

  UserProfile copyWith({String? avatarUrl}) => UserProfile(
    id: id,
    fullName: fullName,
    phone: phone,
    city: city,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  String get displayName =>
      fullName.trim().isEmpty ? 'Apni Gari User' : fullName.trim();

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    id: '${row['id']}',
    fullName: '${row['full_name'] ?? ''}',
    phone: '${row['phone'] ?? ''}',
    city: '${row['city'] ?? ''}',
    avatarUrl: '${row['avatar_url'] ?? ''}',
  );
}
