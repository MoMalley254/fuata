class Routes {
  Routes._();

  // ---- Names (used with context.pushNamed / goNamed) ----
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const home = 'home';
  static const activity = 'activity';
  static const myMoney = 'myMoney';
  static const settings = 'settings';
  static const add = 'add';
  static const unit = 'unit';
  static const inbox = 'inbox';
  static const summary = 'summary';
  static const manageRules = 'manageRules';
  static const ruleBuilderNew = 'ruleBuilderNew';
  static const ruleBuilderEdit = 'ruleBuilderEdit';
  static const limits = 'limits';
  static const banner = 'banner';
  static const autoCatch = 'autoCatch';
  static const backup = 'backup';

  static const profile = 'profile';
  static const settingsHome = 'settingsHome';
  static const settingsDetail = 'settingsDetail';
  static const settingsAppearance = 'settingsAppearance';
  static const settingsPrivacy = 'settingsPrivacy';
  static const settingsCategories = 'settingsCategories';
  static const lock = 'lock';
  static const settingsSecurity = 'settingsSecurity';

  // ---- Paths ----
  static const splashPath = '/splash';
  static const onboardingPath = '/onboarding';
  static const homePath = '/';
  static const activityPath = '/activity';
  static const myMoneyPath = '/my-money';
  static const settingsPath = '/settings';
  static const addPath = '/add';
  static const unitPath = '/unit/:id';
  static const inboxPath = '/inbox';
  static const summaryPath = '/summary';
  static const ruleBuilderNewPath = '/rules/new';
  static const ruleBuilderEditPath = '/rules/edit';
  static const manageRulesPath = '/unit/:id/rules';
  static const limitsPath = '/settings/limits';
  static const bannerPath = '/settings/banner';
  static const autoCatchPath = '/settings/auto-catch';
  static const backupPath = '/settings/backup';
  static const archivedUnits = 'archivedUnits';

  static const profilePath = '/profile';
  static const settingsHomePath = '/settings/home';
  static const settingsDetailPath = '/settings/detail';
  static const settingsAppearancePath = '/settings/appearance';
  static const settingsPrivacyPath = '/settings/privacy';
  static const archivedUnitsPath = '/archived-units';
  static const settingsCategoriesPath = '/settings/categories';
  static const lockPath = '/lock';
  static const settingsSecurityPath = '/settings/security';

  // ---- Helpers ----
  static String unitFor(String id) => '/unit/$id';
  static String manageRulesFor(String unitId) => '/unit/$unitId/rules';
  /// `/rules/new`, optionally pre-set to one unit. The builder falls back
  /// to the first unit if [unitId] is null, so `ruleBuilderNewFor(null)`
  /// is the same as `ruleBuilderNewPath`.
  static String ruleBuilderNewFor(String? unitId) => unitId == null
      ? ruleBuilderNewPath
      : '$ruleBuilderNewPath?unitId=${Uri.encodeQueryComponent(unitId)}';

  /// `/add`, optionally pinned to one unit. The sheet falls back to the
  /// first unit if [unitId] is null.
  static String addFor(String? unitId) => unitId == null
      ? addPath
      : '$addPath?unitId=${Uri.encodeQueryComponent(unitId)}';
}