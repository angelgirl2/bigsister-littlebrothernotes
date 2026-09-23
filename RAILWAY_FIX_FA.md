# اصلاح اتصال آبجی بزرگ و داداش کوچیکه

این نسخه دیگر آدرس Railway را از کاربر نمی‌خواهد و صفحه ورود فقط یک رمز می‌گیرد. سرور از روی رمز تشخیص می‌دهد واردشونده آبجی بزرگ است یا داداش کوچیکه.

## متغیرهای Railway

در Service مربوط به API این موارد را تنظیم کن:

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<حداقل 32 کاراکتر تصادفی>
LITTLE_BROTHER_PASSWORD=<رمز داداش کوچیکه>
BIG_SISTER_PASSWORD=<رمز آبجی بزرگ>
LITTLE_BROTHER_LABEL=داداش کوچیکه
BIG_SISTER_LABEL=آبجی بزرگ
CORS_ORIGIN=*
MEDIA_DIR=/data/media
MAX_UPLOAD_MB=25
```

نسخه سرور هنوز `ME_PASSWORD` و `SISTER_PASSWORD` قدیمی را هم به‌عنوان fallback می‌پذیرد، اما بهتر است نام‌های جدید را تنظیم کنی.

## PostgreSQL و Volume

- یک PostgreSQL در همان Project داشته باش.
- `DATABASE_URL` را با Reference Variable وصل کن.
- برای API یک Volume با Mount Path زیر بساز:

```text
/data/media
```

## Healthcheck

Healthcheck Path:

```text
/api/health
```

باید بعد از آماده‌شدن PostgreSQL پاسخ `200` بدهد.

## APK

URL داخل برنامه مخفی است. برای Build، اگر دامنه فعلی همان دامنه پیش‌فرض پروژه است، دستور زیر کافی است:

```bash
flutter build apk --release
```

اگر دامنه Railway پروژه‌ات متفاوت شده است، فقط هنگام Build مقدار واقعی را داخل `--dart-define` بده؛ آدرس همچنان در UI برنامه نمایش داده نمی‌شود:

```bash
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://YOUR-RAILWAY-DOMAIN
```

## رفتار جدید

- آبجی بزرگ: فقط رمز خودش را وارد می‌کند.
- داداش کوچیکه: فقط رمز خودش را وارد می‌کند.
- کد و PIN جفت‌سازی در رابط کاربری استفاده نمی‌شود.
- آدرس Railway در صفحه ورود نمایش داده نمی‌شود.
- یادداشت‌ها بین دو دستگاه Sync می‌شوند.
- چت به همان اتاق مشترک متصل می‌شود.
- نامه‌ها در جدول جداگانه روی سرور ذخیره می‌شوند و مستقیماً برای طرف مقابل قابل مشاهده‌اند.
- نمونه نامه‌ها دیگر داخل یادداشت‌های محلی ذخیره نمی‌شوند.
