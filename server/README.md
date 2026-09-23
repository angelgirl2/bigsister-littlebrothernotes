# Big Sister Notes — Private Two-Person VPS Server

این سرور برای یک دفتر خصوصی دو نفره («من» و «آبجی») طراحی شده و همه داده‌های Sync و Chat روی همان VPS نگهداری می‌شوند. Firebase/Supabase/Firestore لازم نیست.

## چه چیزهایی همگام می‌شوند؟
- یادداشت‌های متنی
- چک‌لیست‌ها
- نامه‌ها
- خاطره‌ها
- تاریخ و زمان ایجاد/ویرایش
- عکس‌ها و صداهای متصل به Note
- Tag، Favorite، Pin و پوشه
- وضعیت سطل زباله و حذف دائمی با tombstone برای جلوگیری از برگشت داده حذف‌شده
- یادآوری متعلق به هر Note
- چت خصوصی 1:1: متن، عکس، صدا و فایل
- typing، online/offline، delivered/read و reaction ❤️

تقویم خاطرات از داده‌های مشترک Note ساخته می‌شود، بنابراین نیاز به Sync جداگانه ندارد.

## معماری
```text
Android App (من) ─┐
                  ├── HTTPS + Socket.IO ──> Big Sister API ──> PostgreSQL
Android App (آبجی)┘                         │
                                            └── /data/media
```

## اجرای مستقیم روی VPS ایرانی
این پروژه provider-agnostic است؛ کافی است VPS لینوکسی ایرانی با Docker/Compose داشته باشی. هیچ سرویس ابری خارجی برای دیتای برنامه موردنیاز نیست.

### 1) آماده‌سازی
```bash
cd server
cp .env.example .env
nano .env
```

مقادیر `POSTGRES_PASSWORD` و `JWT_SECRET` را حتماً عوض کن و `DOMAIN` را روی دامنه‌ای که به IP VPS اشاره می‌کند قرار بده.

### 2) اجرای production با HTTPS
```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Caddy جلوی API قرار می‌گیرد و برای دامنه HTTPS می‌گیرد. برای تست بدون دامنه می‌توانی فقط `docker-compose.yml` را اجرا کنی و از `http://IP:3000` استفاده کنی؛ برای انتشار عمومی HTTPS استفاده کن.

### 3) تست سرور
برای Compose تستی:
```bash
curl http://127.0.0.1:3000/api/health
```
برای Production با Caddy:
```bash
curl https://notes.example.ir/api/health
```

پاسخ سالم باید شامل `ok: true` باشد.

### 4) بکاپ PostgreSQL
```bash
bash scripts/backup.sh
```

این اسکریپت هم Dump دیتابیس PostgreSQL و هم آرشیو Volume عکس/صوت/فایل را در پوشه `server/backups` می‌سازد و نسخه‌های قدیمی‌تر از ۱۴ روز را حذف می‌کند.

## اتصال Flutter
می‌توانی آدرس VPS را از تنظیمات برنامه وارد کنی. یا زمان Build:

```bash
flutter build apk --release --dart-define=BIG_SISTER_API_URL=https://notes.example.ir
```

## Pairing
ورود جدید فقط با رمز انجام می‌شود: داداش کوچیکه رمز خودش را وارد می‌کند.
2. کد ۸ کاراکتری و PIN شش‌رقمی را به گوشی دوم بده.
3. گوشی دوم: همان صفحه → رمز آبجی بزرگ → وارد کردن Code + PIN.
4. پس از Pair شدن، Sync خودکار فعال می‌شود.

## نکات مهم امنیتی
- JWT روی هر دستگاه به‌صورت Secure Storage نگه‌داری می‌شود.
- فقط دو نقش `me` و `sister` در هر اتاق وجود دارد.
- Media فقط با JWT همان Room قابل دریافت است.
- فایل پیوست قبل از ثبت پیام بررسی می‌شود که متعلق به همان Room باشد.
- برای استفاده عمومی پورت PostgreSQL را روی اینترنت باز نکن.
- روی VPS فقط پورت‌های 80/443 را عمومی نگه دار؛ پورت 5432 را فایروال کن.
- `.env` را داخل Git قرار نده.

## Login

The app does not use a pairing code or pairing PIN. The server owns two accounts (`me` and `sister`) with passwords configured by environment variables. Each phone logs in once and stores its session token securely.


## Railway

برای Railway از Dockerfile ریشه پروژه استفاده شده است. در Railway دو Service بساز:

- PostgreSQL
- API از همین repository

روی API متغیرهای `DATABASE_URL`, `JWT_SECRET`, `LITTLE_BROTHER_PASSWORD`, `BIG_SISTER_PASSWORD` و بقیه متغیرهای `.env.example` را تنظیم کن. `DATABASE_URL` را با Reference Variable به `Postgres.DATABASE_URL` وصل کن. `PORT` را دستی تنظیم نکن.

برای فایل‌های عکس/صدا/فایل یک Railway Volume با mount path زیر بساز:

```text
/data/media
```

Healthcheck:

```text
/api/health
```

بعد از Generate Domain، همان HTTPS URL را در برنامه Flutter وارد کن.

راهنمای کامل Railway در فایل ریشه `RAILWAY.md` قرار دارد.
