# راه‌اندازی دفتر مشترک روی Railway ❤️🫂

این نسخه برای **یک دفتر مشترک دوطرفه** تنظیم شده است. هر چیزی که یکی از دو نفر در برنامه اضافه یا ویرایش کند، روی سرور مشترک ذخیره می‌شود و طرف مقابل هم آن را دریافت می‌کند.

## 1) در Railway

دو سرویس بساز:

- PostgreSQL
- Big Sister API

روی API یک Volume با این Mount Path بساز:

```text
/data/media
```

## 2) Variables سرویس API

```text
NODE_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<حداقل 32 کاراکتر تصادفی>
CORS_ORIGIN=*
MEDIA_DIR=/data/media
MAX_UPLOAD_MB=25
SHARED_ROOM_KEY=big-sister-private-room
LITTLE_BROTHER_PASSWORD=<رمز من>
BIG_SISTER_PASSWORD=<رمز آبجی>
LITTLE_BROTHER_LABEL=من
BIG_SISTER_LABEL=آبجی
```

`PORT` را دستی نگذار.

## 3) Domain

در Railway برای API گزینه **Generate Domain** را بزن. مثلاً:

```text
https://bigsister-littlebrothernotes.up.railway.app
```

سپس Healthcheck را روی این مسیر بگذار:

```text
/api/health
```

## 4) نصب روی هر دو گوشی

روی هر دو گوشی همان برنامه/همان APK را نصب کن.

گوشی اول:

```text
دفتر مشترک → من → رمز LITTLE_BROTHER_PASSWORD
```

گوشی دوم:

```text
دفتر مشترک → آبجی → رمز BIG_SISTER_PASSWORD
```

هر دو باید **همان URL Railway** را داشته باشند.

## 5) ثابت‌کردن URL داخل APK

```bash
flutter clean
flutter pub get
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://bigsister-littlebrothernotes.up.railway.app
```

بعد دیگر لازم نیست آدرس را دستی وارد کنی؛ فقط نقش و رمز هر نفر متفاوت است.

## 6) چه چیزهایی مشترک است؟

یادداشت‌ها، ویرایش‌ها، حذف/بازگردانی، عکس‌ها، صداهای داخل یادداشت، و چت و فایل‌های چت روی یک فضای مشترک هستند.

Socket.IO تغییرات را به‌صورت زنده اعلام می‌کند و هنگام بازگشت اینترنت، Sync دوباره وضعیت را بررسی می‌کند.

## 7) نکته مهم

در Railway فعلاً API را فقط با **یک replica** اجرا کن. PostgreSQL منبع اصلی داده است و Volume `/data/media` فایل‌های رسانه‌ای را نگه می‌دارد.
