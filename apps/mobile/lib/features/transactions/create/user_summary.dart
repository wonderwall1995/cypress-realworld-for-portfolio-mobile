import '../../../core/person_name.dart';

/// Another user, as shown in the list when choosing who to pay or ask.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.hasBankAccount = true,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        username: json['username'] as String? ?? '',
        // A server that does not say: the user stays in the list.
        hasBankAccount: json['hasBankAccount'] != false,
      );

  final String id;
  final String firstName;
  final String lastName;
  final String username;

  /// Nothing can be sent to a user without a bank account.
  final bool hasBankAccount;

  String get fullName => koreanFullName(firstName: firstName, lastName: lastName);
}
