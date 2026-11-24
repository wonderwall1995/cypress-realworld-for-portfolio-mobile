/// The values the server takes, with the words the user sees.
const privacyChoices = [
  (value: 'public', label: '공개'),
  (value: 'private', label: '비공개'),
];

/// The word for a saved value: 공개 or 비공개.
String privacyLabel(Object? saved) =>
    privacyChoices.firstWhere((c) => c.value == privacyOf(saved)).label;

/// What a saved value means. Nothing saved is public (the server does the same).
/// The old value `contacts` is private: those transactions are not shown to others
/// any more, and the app must not show more than the user chose.
String privacyOf(Object? saved) => switch (saved) {
      'public' || null || '' => 'public',
      _ => 'private',
    };
