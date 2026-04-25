import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  static bool initialized = false;

  static Future<void> init() async {
    if (!initialized) {
      tz.initializeTimeZones();
      initialized = true;
    }
  }

  static DateTime getTime(String zone) {
    final location = tz.getLocation(zone);
    return tz.TZDateTime.now(location);
  }

  static String getCity(String zone) {
    return zone.split('/').last.replaceAll('_', ' ');
  }
}