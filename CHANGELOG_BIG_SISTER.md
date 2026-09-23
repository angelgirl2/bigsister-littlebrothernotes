# Big Sister Note – UI update

- Existing turquoise `assets/logo.png` is now used by the splash screen and home header.
- Added a reusable SVG asset icon system under `assets/icons/`.
- Navigation icons and Home quick actions now use the new asset icons.
- Added `flutter_svg` to `pubspec.yaml`.
- Added centralized Material 3 button theming in `lib/theme/app_theme.dart`.
- Elevated, Filled, Outlined, Text, Icon and Floating Action buttons now derive their colors from the active app theme.
- Theme changes therefore update button colors automatically for Turquoise, Sky, Red and Blue themes.


## 6.1 — دفتر دوطرفه کامل
- Sync دوطرفه Note/Memory/Letter/Checklist/Reminder/Photo/Audio
- Chat خصوصی 1:1 با متن/عکس/صوت/فایل
- Pairing با Code + PIN
- Socket.IO real-time
- Sync مجدد هنگام reconnect
- اعتبارسنجی Attachment بر اساس Room
- رفع مسیرهای Quick Action بعد از اضافه شدن تب Chat

- 6.2: حذف کامل نیاز UI به کد/PIN جفت‌سازی؛ ورود یک‌باره برای نقش من/آبجی و همگام‌سازی خودکار پس از آن.

- 6.2: اتصال دوطرفه بدون کد/PIN جفت‌سازی؛ ورود یک‌باره با رمز حساب VPS برای نقش من/آبجی و Sync خودکار پس از آن.
