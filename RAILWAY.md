# استقرار Big Sister Notes روی Railway

این پروژه برای Railway آماده شده است. سرویس Railway فقط Backend داخل `server/` را به‌صورت Docker اجرا می‌کند؛ Flutter/Android همچنان کلاینت برنامه است.

## معماری

```text
Flutter Android
      │
      │ HTTPS + WebSocket
      ▼
Railway Web Service (Node + Express + Socket.IO)
      │
      ├── Railway PostgreSQL
      │
      └── Railway Volume → /data/media
```

## 1) ساخت پروژه

این نسخه در حالت **یک دفتر کاملاً مشترک** کار می‌کند: یک اتاق مشترک روی سرور ساخته می‌شود و دو نفر با دو نقش `من` و `آبجی` وارد همان اتاق می‌شوند. برای همگام‌سازی یادداشت‌ها، عکس‌ها و صداهای داخل یادداشت، هر دو گوشی باید به همان Railway URL وصل شوند.

در Railway یک Project جدید بساز و دو Service داشته باش:

1. **Postgres** → از + New → Database → PostgreSQL
2. **Big Sister API** → از GitHub Repo همین پروژه

برای سرویس API، چون Dockerfile در ریشه پروژه قرار دارد، Root Directory را روی `/` بگذار یا خالی نگه دار.

## 2) متغیرهای API

در Service مربوط به API در Variables این‌ها را تنظیم کن:

```text
NODE_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<یک مقدار تصادفی طولانی، حداقل 32 کاراکتر>
CORS_ORIGIN=*
MEDIA_DIR=/data/media
MAX_UPLOAD_MB=25
ROOM_CODE_TTL_HOURS=24

SHARED_ROOM_KEY=big-sister-private-room

# اختیاری: اگر اپ را با این مقدار build کنی، آدرس Railway داخل برنامه از قبل قرار می‌گیرد.
# BIG_SISTER_API_URL=https://YOUR-APP.up.railway.app
ME_PASSWORD=<رمز نفر اول>
SISTER_PASSWORD=<رمز نفر دوم>
ME_LABEL=من
SISTER_LABEL=آبجی
```

اگر اسم سرویس PostgreSQL را چیز دیگری گذاشتی، `Postgres` در Reference Variable را با نام واقعی همان Service عوض کن. Railway برای PostgreSQL متغیر `DATABASE_URL` را در اختیار سرویس قرار می‌دهد. برای اتصال داخلی، از Reference Variable استفاده کن و URL دیتابیس را دستی هاردکد نکن.

**`PORT` را دستی تعیین نکن.** Railway مقدار `PORT` را تزریق می‌کند و سرور همین مقدار را روی `0.0.0.0` گوش می‌دهد.

## 3) Volume برای عکس، صدا و فایل

روی Service مربوط به API یک Volume بساز و Mount Path را دقیقاً بگذار:

```text
/data/media
```

بدون Volume، فایل‌های آپلودشده روی filesystem موقتی می‌مانند و بعد از deployment/restart ممکن است از بین بروند.

## 4) Healthcheck

در Service → Settings → Healthcheck Path این مسیر را بگذار:

```text
/api/health
```

این endpoint فقط وقتی `200` می‌دهد که اتصال PostgreSQL سالم باشد.

## 5) Networking

در Service مربوط به API گزینه Generate Domain را بزن. آدرس HTTPS ساخته‌شده را بردار؛ مثلاً:

```text
https://big-sister-api.up.railway.app
```

همان URL را داخل برنامه Flutter در صفحه «دفتر مشترک» وارد کن.

Socket.IO هم از همان دامنه و HTTPS استفاده می‌کند؛ نیازی به Caddy یا reverse proxy جداگانه روی Railway نیست.

## 6) Deploy

بعد از Deploy فقط یک URL داری و همان URL را روی **هر دو گوشی** استفاده می‌کنی. روی گوشی اول نقش `من` و رمز `ME_PASSWORD` و روی گوشی دوم نقش `آبجی` و رمز `SISTER_PASSWORD` را انتخاب کن. بعد از اولین ورود، نشست ذخیره می‌شود و Socket.IO و همگام‌سازی خودکار فعال هستند.

بعد از Push به GitHub، Railway خودش Dockerfile ریشه را تشخیص می‌دهد. ساختار Dockerfile ریشه طوری تنظیم شده که فقط Backend را در image قرار دهد:

```text
server/package.json
server/src/
server/schema.sql
```

## 7) بررسی بعد از Deploy

در مرورگر یا curl:

```text
https://YOUR-RAILWAY-DOMAIN/api/health
```

پاسخ سالم:

```json
{
  "ok": true,
  "service": "big-sister-sync"
}
```

همچنین ریشه سرویس:

```text
https://YOUR-RAILWAY-DOMAIN/
```

یک JSON ساده برای تست برمی‌گرداند.

## 8) اتصال Flutter

### حالت پیشنهادی برای APK
اگر URL Railway را از قبل داری، APK را این‌طور بساز تا لازم نباشد آدرس را هر بار دستی وارد کنی:

```bash
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://YOUR-APP.up.railway.app
```

هر دو گوشی می‌توانند همین APK را نصب کنند؛ فقط نقش و رمز ورود هر کدام متفاوت است.

در برنامه:

**تنظیمات → دفتر مشترک → آدرس Railway**

و URL سرویس Railway را وارد کن:

```text
https://YOUR-RAILWAY-DOMAIN
```

بعد نقش `من` یا `آبجی` و رمز مربوطه را انتخاب کن.

برای Build با URL ثابت هم می‌توانی استفاده کنی:

```bash
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://YOUR-RAILWAY-DOMAIN
```

## 9) چه چیزهایی بین دو گوشی مشترک است؟

- یادداشت‌ها، ویرایش‌ها، حذف/بازگردانی و وضعیت یادداشت‌ها
- عکس‌ها و صداهای داخل یادداشت‌ها
- فایل‌ها و عکس‌ها و پیام‌های بخش چت
- وضعیت آنلاین/آفلاین و خوانده‌شدن پیام‌ها

هر چیزی که یک نفر روی دستگاه خودش اضافه یا ویرایش کند، با اتصال اینترنت به دفتر مشترک روی سرور می‌رود و دستگاه دیگر از طریق Socket.IO اعلان تغییر می‌گیرد.

## 10) نکته مهم درباره مقیاس‌دهی

این Backend در وضعیت فعلی باید با **یک replica** اجرا شود، چون Socket.IO وضعیت اتصال را در حافظه نگه می‌دارد و فایل‌های media نیز روی Volume محلی همان Service ذخیره می‌شوند. تا وقتی Redis برای Socket.IO و Object Storage برای media اضافه نشده، تعداد replica را افزایش نده.

## 11) مواردی که برای Railway اصلاح شده‌اند

- استفاده از `process.env.PORT` و listen روی `0.0.0.0`
- endpoint ریشه برای smoke test
- healthcheck قابل استفاده توسط Railway در `/api/health`
- Volume path استاندارد `/data/media`
- اتصال PostgreSQL از `DATABASE_URL`
- اصلاح bug مربوط به `req` در `/api/pair/create`
- همگام‌سازی واقعی media یادداشت‌ها با شناسه‌های دائمی روی Railway Volume
- deduplication رسانه‌ها با SHA-256 تا یک عکس/صدا دوباره بی‌دلیل آپلود نشود
- پشتیبانی از `BIG_SISTER_API_URL` برای ثابت‌کردن URL داخل APK
- تعریف `ROOM_CODE_TTL_HOURS` که قبلاً در کد استفاده می‌شد ولی تعریف نشده بود
- Dockerfile ریشه برای deploy مستقیم از root repository
- `.dockerignore` برای جلوگیری از ورود فایل‌های غیرضروری و secrets به build context

## متغیرهای Secret

این موارد را داخل Git commit نکن:

- `JWT_SECRET`
- `ME_PASSWORD`
- `SISTER_PASSWORD`
- `DATABASE_URL`
- هر credential دیگری

این‌ها باید در Railway Variables باشند.
