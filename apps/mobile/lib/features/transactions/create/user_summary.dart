/// Another user, as shown in the list when choosing who to pay or ask.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        username: json['username'] as String? ?? '',
      );

  final String id;
  final String firstName;
  final String lastName;
  final String username;

  String get fullName => '$firstName $lastName'.trim();
}
