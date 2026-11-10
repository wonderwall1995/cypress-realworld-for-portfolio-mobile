/// A full name the Korean way: the family name (성) first, then the given name
/// (이름). The server builds the names it sends (`senderName`, `receiverName`,
/// `userFullName`) in this order, so the names the app builds from a user's
/// `lastName` and `firstName` follow the same order.
String koreanFullName({String? firstName, String? lastName}) =>
    '${lastName ?? ''} ${firstName ?? ''}'.trim();
