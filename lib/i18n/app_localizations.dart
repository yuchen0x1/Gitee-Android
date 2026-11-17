import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('zh', 'CN'));

  String t(String key) => _values[locale.languageCode]?[key] ??
      _values['zh']![key] ?? key;
}

const _values = <String, Map<String, String>>{
  'zh': {
    'profile': '我的',
    'preferences': '偏好',
    'language': '界面语言',
    'auto': '自动（跟随系统）',
    'simplifiedChinese': '简体中文',
    'english': 'English',
    'languageApplied': '界面语言已更新',
  },
  'en': {
    'profile': 'Profile',
    'preferences': 'Preferences',
    'language': 'Interface language',
    'auto': 'Automatic (system)',
    'simplifiedChinese': 'Simplified Chinese',
    'english': 'English',
    'languageApplied': 'Interface language updated',
  },
};

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
