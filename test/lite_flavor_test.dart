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
        'klasik',
        'klasik_2',
        'klasik_3',
        'klasik_4',
        'klasik_5',
        'kucing',
        'bebek',
        'call_duck',
        'spongebob',
      });
      final settings = SettingsProvider();
      SharedPreferences.setMockInitialValues({'themeId': 'tema_lama'});
      await settings.load();
      expect(settings.availableThemes.last.id, 'custom');

      expect(settings.preset.id, 'klasik');
    },
    skip: appFlavor != 'lite',
  );
}
