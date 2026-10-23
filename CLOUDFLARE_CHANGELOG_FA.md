# گزارش تغییرات Cloudflare

این تغییرات به‌صورت افزایشی روی پروژه قرار گرفته‌اند؛ فایل‌های backend فعلی Railway/Node/PostgreSQL و امکانات موجود حذف نشده‌اند.

## فایل‌های جدید

- `cloudflare/src/index.js`: API سازگار با مسیرهای مورد استفادهٔ برنامه، JWT، snapshot، chat، letters، media، history و Durable Objects WebSocket.
- `cloudflare/migrations/0001_initial.sql`: ساخت جداول D1 شامل جدول قطعه‌های رسانه.
- `cloudflare/wrangler.toml` و `.example`: اتصال D1 و Durable Objects.
- `.github/workflows/deploy-cloudflare.yml`: استقرار Worker و اجرای migration از GitHub Actions.
- `cloudflare/README_FA.md`: دستورالعمل فارسی نصب و راه‌اندازی.

## سازگاری افزوده‌شده

- `lib/cloud/cloud_service.dart` همچنان از Socket.IO برای Railway استفاده می‌کند؛ وقتی سرور Cloudflare تشخیص داده شود از WebSocket استاندارد Cloudflare استفاده می‌کند.
- اگر snapshot واقعی هنوز روی دیتابیس Cloudflare ساخته نشده باشد، برنامه payload خالی را روی یادداشت‌های محلی اعمال نمی‌کند؛ اولین sync محتوای محلی را به Cloudflare می‌فرستد.
- URL پیش‌فرض فعلی Railway دست‌نخورده است. آدرس Cloudflare را بعد از استقرار می‌توان از تنظیمات برنامه یا متغیر GitHub با نام `BIG_SISTER_API_URL` تعیین کرد.

## بررسی‌هایی که انجام شد

- بررسی نحوی JavaScript با `node --check` موفق بود.
- schema جداول با SQLite اجرا شد.
- آزمون smoke با SQLite محلی برای health، ورود دو نقش، snapshot sync، پیام، نامه، upload/download رسانهٔ قطعه‌بندی‌شده، edit/pin/reaction/read/delete و وضعیت اتاق موفق بود.
- APK با Flutter SDK در این محیط ساخته نشده است؛ بنابراین build نهایی Android هنوز باید در GitHub Actions یا روی سیستم دارای Flutter/Android SDK بررسی شود.

## داده‌ها

این افزونه دیتابیس تازه می‌سازد و داده‌های موجود PostgreSQL/Railway را خودکار منتقل نمی‌کند. سرویس Railway و دیتابیس فعلی حذف نشده‌اند. پیش از تغییر URL گوشی‌ها، از داده‌ها backup بگیر و برای انتقال تاریخچهٔ پیام‌ها/نامه‌ها/رسانه‌های موجود برنامه‌ریزی جداگانه داشته باش.
