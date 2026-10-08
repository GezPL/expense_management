import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Cài đặt thông báo nhắc nhở
class ReminderSettings {
  final bool isEnabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    required this.isEnabled,
    required this.hour,
    required this.minute,
  });
}

/// Dịch vụ quản lý thông báo nội bộ (Local Notifications) 100% On-device
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const int dailyReminderId = 1001;
  static const String _prefEnabledKey = 'notification_reminder_enabled';
  static const String _prefHourKey = 'notification_reminder_hour';
  static const String _prefMinuteKey = 'notification_reminder_minute';

  /// Khởi tạo dịch vụ thông báo và timezone
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Khởi tạo cơ sở dữ liệu múi giờ cho lịch thông báo định kỳ
      tz.initializeTimeZones();

      // 2. Cấu hình icon thông báo trên Android & quyền trên iOS
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Đã bấm vào thông báo: ${details.payload}');
        },
      );

      // 3. Yêu cầu quyền thông báo trên Android 13+ (API 33+)
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      _isInitialized = true;

      // 4. Đồng bộ lịch nhắc nhở đã lưu trong SharedPreferences
      final settings = await getReminderSettings();
      if (settings.isEnabled) {
        await scheduleDailyReminder(hour: settings.hour, minute: settings.minute);
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo NotificationService: $e');
    }
  }

  /// Lấy cấu hình nhắc nhở hiện tại
  Future<ReminderSettings> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_prefEnabledKey) ?? true; // Mặc định bật
    final hour = prefs.getInt(_prefHourKey) ?? 20; // 20h tối mặc định
    final minute = prefs.getInt(_prefMinuteKey) ?? 0;
    return ReminderSettings(isEnabled: isEnabled, hour: hour, minute: minute);
  }

  /// Bật / Tắt nhắc nhở hàng ngày
  Future<void> toggleReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);

    if (enabled) {
      final settings = await getReminderSettings();
      await scheduleDailyReminder(hour: settings.hour, minute: settings.minute);
    } else {
      await cancelDailyReminder();
    }
  }

  /// Cập nhật giờ nhắc nhở định kỳ
  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHourKey, hour);
    await prefs.setInt(_prefMinuteKey, minute);

    final isEnabled = prefs.getBool(_prefEnabledKey) ?? true;
    if (isEnabled) {
      await scheduleDailyReminder(hour: hour, minute: minute);
    }
  }

  /// Lập lịch thông báo nhắc nhở lặp lại mỗi ngày
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    if (!_isInitialized) {
      debugPrint('NotificationService chưa được khởi tạo, bỏ qua đặt lịch platform.');
      return;
    }
    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);

      const androidDetails = AndroidNotificationDetails(
        'daily_expense_reminder',
        'Nhắc nhở chi tiêu hàng ngày',
        channelDescription: 'Thông báo nhắc nhở ghi chép hóa đơn định kỳ mỗi tối',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: dailyReminderId,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Nhắc nhở chi tiêu hôm nay 📝',
        body: 'Đừng quên cập nhật các khoản chi tiêu trong ngày để quản lý ngân sách hiệu quả nhé!',
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Đã đặt lịch nhắc nhở mỗi ngày vào lúc $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Lỗi đặt lịch thông báo: $e');
    }
  }

  /// Hủy bỏ lịch nhắc nhở
  Future<void> cancelDailyReminder() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id: dailyReminderId);
      debugPrint('Đã hủy lịch nhắc nhở chi tiêu.');
    } catch (e) {
      debugPrint('Lỗi hủy thông báo: $e');
    }
  }

  /// Gửi ngay một thông báo thử nghiệm (Test notification)
  Future<void> sendTestNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'daily_expense_reminder',
        'Nhắc nhở chi tiêu hàng ngày',
        channelDescription: 'Thông báo nhắc nhở ghi chép hóa đơn định kỳ mỗi tối',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: 9999,
        title: 'Thông báo thử nghiệm 🔔',
        body: 'Hệ thống thông báo nhắc nhở chi tiêu đã hoạt động hoàn hảo!',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Lỗi gửi thông báo thử nghiệm: $e');
    }
  }

  /// Tính toán thời điểm tiếp theo cho giờ:phút định kỳ
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
