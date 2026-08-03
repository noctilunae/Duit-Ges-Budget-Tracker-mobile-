import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duit_ges/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'flavor Lite hanya membawa tema pilihan dan fallback aman',
    () async {
      expect(appFlavor, 'lite');
      expect(themePresets.map((theme) => theme.id), {
        'kucing',
        'bebek',
        'call_duck',
      });
      final settings = SettingsProvider();
      SharedPreferences.setMockInitialValues({'themeId': 'jjk2'});
      await settings.load();
      expect(settings.availableThemes.last.id, 'custom');

      expect(settings.preset.id, 'kucing');
    },
    skip: appFlavor != 'lite',
  );
}
