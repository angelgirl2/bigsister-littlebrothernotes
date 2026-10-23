# راه‌اندازی Cloudflare برای Big Sister Notes (بدون حذف Railway)

این پوشه یک backend جایگزین Cloudflare است. کد Flutter فعلی، API فعلی Node.js/Socket.IO، Docker، تنظیمات Railway، فایل‌ها و migrationهای پروژه حذف نشده‌اند. با توجه به اینکه Flutter قبلاً از Socket.IO استفاده می‌کرد، برای Cloudflare یک WebSocket استاندارد با رویدادهای همان نام‌ها اضافه شده است.

## اجزا

- Workers: API با قراردادهای `/api/...` موردنیاز برنامه.
- D1: حساب اتاق مشترک، نشست‌ها، یادداشت‌های همگام‌شده، پیام‌ها، نامه‌ها، تاریخچه تماس و metadata رسانه‌ها.
- D1 BLOB chunks: فایل‌ها در قطعات 200 KiB ذخیره می‌شوند. این روش از الزام به ساخت اشتراک R2 دوری می‌کند تا نصب اولیه بتواند روی سهمیهٔ رایگان بماند. در عوض، رسانه‌ها بخشی از سهمیه و فضای D1 را مصرف می‌کنند و دانلود یک فایل بزرگ چند پرس‌وجوی کوچک دارد. این روش برای بار سبک دو نفره طراحی شده است.
- Durable Objects: WebSocket زنده برای پیام، حضور آنلاین، تایپ‌کردن و سیگنال‌دهی تماس.
- GitHub Actions: مخزن GitHub منبع اصلی کد است؛ هر Push به `main` یا `master` با تغییر `cloudflare/**` می‌تواند Worker را منتشر کند.

Cloudflare سهمیه‌های رایگان دارد، اما هیچ سرویس ابری را نمی‌توان بدون قید و شرط برای همیشه رایگان تضمین کرد. عبور از سهمیه‌های روزانه می‌تواند درخواست‌های بیشتر را متوقف کند. این نسخه عمداً به R2 وابسته نیست، چون فعال کردن R2 وارد مرحلهٔ subscription/checkout می‌شود.

## یک‌بار راه‌اندازی Cloudflare

1. در داشبورد Cloudflare، یک D1 database با نام دقیق `big-sister-db` بساز: <https://dash.cloudflare.com/> → **Storage & databases → D1 SQL Database**. در این مرحله هنوز چیزی از Railway حذف نمی‌شود.
2. شناسهٔ UUID دیتابیس را کپی کن.
3. در مخزن GitHub برو به **Settings → Secrets and variables → Actions → Variables → New repository variable** و متغیر `CF_D1_DATABASE_ID` را با UUID بالا ایجاد کن.
4. در **Settings → Secrets and variables → Actions → Secrets** این Secrets را ایجاد کن:
   - `CLOUDFLARE_API_TOKEN` — توکن با مجوزهای لازم برای Worker deployment و D1 migrations در همان حساب.
   - `CLOUDFLARE_ACCOUNT_ID` — شناسهٔ حساب Cloudflare.
   - `JWT_SECRET` — یک مقدار تصادفی قوی حداقل 32 نویسه.
   - `SHARED_ROOM_KEY` — مقدار تصادفی قوی جداگانه، حداقل 32 نویسه.
   - `LITTLE_BROTHER_PASSWORD` — همان رمز مورد استفادهٔ برادر در برنامه.
   - `BIG_SISTER_PASSWORD` — همان رمز مورد استفادهٔ خواهر در برنامه.
5. در شاخهٔ `main` این پوشه و workflow را به مخزن GitHub خودت Push کن. به **Actions → Deploy Big Sister API to Cloudflare → Run workflow** برو و اجرا را شروع کن. می‌توانی بعداً فقط با Push کردن تغییرات `cloudflare/` آن را منتشر کنی.
6. در پایان، آدرس Worker معمولاً شبیه `https://big-sister-sync-cloudflare.<SUBDOMAIN>.workers.dev` خواهد بود. در مرورگر یا PowerShell این endpoint را باز کن: `/api/health`. پاسخ سالم باید `"ok":true` و `"provider":"cloudflare-workers"` داشته باشد.

> اگر ساخت D1 را از داشبورد انجام می‌دهی، دیتابیس باید در همان حساب Cloudflare باشد که `CLOUDFLARE_ACCOUNT_ID` به آن اشاره می‌کند. شناسهٔ D1 باید دقیقاً UUID همان دیتابیس باشد. Worker بدون secrets فوق عمداً login را قبول نمی‌کند.

## اتصال برنامهٔ Flutter

در تنظیمات برنامه، آدرس اصلی Worker را (بدون `/api/health` و بدون مسیر انتهایی) وارد و گزینهٔ تست اتصال را اجرا کن. نمونه:

`https://big-sister-sync-cloudflare.<SUBDOMAIN>.workers.dev`

همچنین می‌توانی در GitHub repository **Variable** با نام `BIG_SISTER_API_URL` بسازی و مقدار آن را برابر URL نهایی Worker قرار بدهی؛ workflow ساخت APK موجود از این متغیر استفاده می‌کند. اگر این متغیر تنظیم نشود، رفتار قبلی و آدرس پیش‌فرض Railway حفظ می‌شود.

## داده‌های فعلی Railway — نکتهٔ حیاتی

**این backend دیتابیس جدید و خالی ایجاد می‌کند. داده‌های PostgreSQL، پیام‌ها، نامه‌ها و فایل‌های موجود Railway به‌طور خودکار به D1 منتقل نمی‌شوند.** کد فعلی Railway و volumeها تغییری نمی‌کنند و چیزی از آنجا پاک نمی‌شود؛ بااین‌حال، قبل از وارد کردن URL جدید در برنامه، از Railway PostgreSQL و رسانه‌ها نسخهٔ پشتیبان بگیر. اگر یادداشت‌های محلی برنامه در گوشی وجود داشته باشند، با Sync در Cloudflare قابل بارگذاری‌اند؛ اما این به معنی انتقال خودکار تاریخچهٔ پیام/نامه/رسانه‌های تنها-روی-Railway نیست.

برای تغییر نهایی URL هر دو گوشی باید به همین Worker اشاره کنند. این URL و توکن‌ها را در کانال عمومی منتشر نکن.

## آزمون smoke

- `GET /api/health` → `ok: true`, `provider: cloudflare-workers`.
- در برنامه، با رمز برادر وارد شو؛ سپس در گوشی خواهرت با رمز خواهر وارد شو.
- یادداشت متنی، عکس کوچک، پیام متنی، نامه، وضعیت آنلاین، تایپ‌کردن و سیگنال تماس را جداگانه آزمایش کن.
- در Cloudflare Dashboard کنترل کن که D1 space / row limits استفاده نشده باشد.

## محدودیت‌ها

- سهمیه‌های پلن رایگان محدود هستند. ذخیرهٔ media در D1 نسبت به R2 پرهزینه‌تر از نظر تعداد عملیات D1 است؛ برای فایل‌های حجیم زیاد، ابتدا backup/export و سپس طراحی R2 را بررسی کن.
- تماس‌های صوتی/تصویری همچنان به مجوزهای میکروفون/دوربین و NAT traversal/WebRTC در گوشی‌ها نیاز دارند؛ این Worker فقط سیگنال‌دهی دوطرفه را منتقل می‌کند و خودش relay رسانهٔ تماس نیست.
- نسخهٔ اول Cloudflare جایگزین Node/PostgreSQL نمی‌شود مگر خودت URL را تغییر دهی. مسیر Railway در پروژه باقی است.
