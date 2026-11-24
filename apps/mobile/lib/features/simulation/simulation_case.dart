enum SimulationCase {
  auth('000', '000-auth.spec.ts'),
  bankAccount('001', '001-bank-account.spec.ts'),
  deposit('002', '002-deposit.spec.ts'),
  transfer('003', '003-transfer.spec.ts'),
  detail('004', '004-transaction-detail.spec.ts'),
  filter('005', '005-transaction-filter.spec.ts'),
  settings('006', '006-user-settings.spec.ts'),
  visibility('007', '007-transaction-visibility.spec.ts'),
  notifications('008', '008-notifications.spec.ts'),
  loginLogout('009', '009-login-logout.spec.ts');

  const SimulationCase(this.code, this.fileName);
  final String code;
  final String fileName;
  String get label => fileName;
}
