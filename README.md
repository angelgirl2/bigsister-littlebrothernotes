# Big Sister Notes ❤️🫂 — دفتر مشترک دوطرفه

این پروژه یک دفتر یادداشت خصوصی دو نفره برای «من ↔ آبجی» است. یادداشت، چک‌لیست، نامه، خاطره، تاریخ، عکس، فایل صوتی و چت روی سرور Railway (PostgreSQL + Volume) ذخیره و بین دو دستگاه همگام می‌شوند.

## اتصال بدون Code / PIN جفت‌سازی

این نسخه هیچ صفحه‌ای برای وارد کردن کد دفتر یا PIN جفت‌سازی ندارد. هر شخص فقط یک بار با نقش خودش و **رمز ورود حساب Railway** وارد می‌شود. پس از آن Session روی دستگاه ذخیره می‌شود و در اجراهای بعدی همگام‌سازی خودکار انجام می‌شود.

### راه‌اندازی Railway

```bash
cd server
cp .env.example .env
```

در `.env` مقدارهای `POSTGRES_PASSWORD`، `JWT_SECRET`، `SHARED_ROOM_KEY`، `LITTLE_BROTHER_PASSWORD` و `BIG_SISTER_PASSWORD` را تنظیم کن. سپس:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

تست:

```bash
curl https://bigsister-littlebrothernotes.up.railway.app/api/health
```

### روی هر دو گوشی

در برنامه:

```text
تنظیمات → دفتر مشترک
→ انتخاب «من» یا «آبجی»
→ ورود رمز حساب
→ ورود و اتصال خودکار
```

بعد از آن دیگر Code/PIN جفت‌سازی در کار نیست.

## رفتار Sync

در اولین اتصال، محتویات موجود از VPS دریافت می‌شوند. تغییرات محلی به VPS ارسال می‌شوند و Socket.IO تغییرات طرف مقابل را به‌صورت زنده اطلاع می‌دهد. در حالت آفلاین داده محلی باقی می‌ماند و در اتصال بعدی مجدداً همگام می‌شود.

## امنیت

رمزهای دو حساب فقط در Railway Variables هستند و داخل APK نوشته نمی‌شوند. HTTPS و یک `JWT_SECRET` طولانی استفاده کن. پورت PostgreSQL را عمومی نکن.

## APK

اگر آدرس Railway را هنگام Build می‌خواهی ثابت کنی:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://bigsister-littlebrothernotes.up.railway.app
```
