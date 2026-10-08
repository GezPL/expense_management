import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_management/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Reminder Settings Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Lấy cấu hình mặc định (Bật, 20:00)', () async {
      final settings = await NotificationService.instance.getReminderSettings();
      expect(settings.isEnabled, isTrue);
      expect(settings.hour, 20);
      expect(settings.minute, 0);
    });

    test('Bật / tắt trạng thái thông báo nhắc nhở thành công', () async {
      await NotificationService.instance.toggleReminder(false);
      var settings = await NotificationService.instance.getReminderSettings();
      expect(settings.isEnabled, isFalse);

      await NotificationService.instance.toggleReminder(true);
      settings = await NotificationService.instance.getReminderSettings();
      expect(settings.isEnabled, isTrue);
    });

    test('Cập nhật mốc thời gian nhắc nhở chi tiêu mới thành công', () async {
      await NotificationService.instance.setReminderTime(21, 30);
      final settings = await NotificationService.instance.getReminderSettings();
      expect(settings.hour, 21);
      expect(settings.minute, 30);
    });
  });
}

