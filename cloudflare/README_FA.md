# راه‌اندازی Cloudflare برای Big Sister Notes (بدون حذف Railway)

این پوشه یک backend جایگزین Cloudflare است. کد Flutter فعلی، API فعلی Node.js/Socket.IO، Docker، تنظیمات Railway، فایل‌ها و migrationهای پروژه حذف نشده‌اند. با توجه به اینکه Flutter قبلاً از Socket.IO استفاده می‌کرد، برای Cloudflare یک WebSocket استاندارد با رویدادهای همان نام‌ها اضافه شده است.

## اجزا

- Workers: API با قراردادهای `/api/...` موردنیاز برنامه.
- D1: حساب اتاق مشترک، نشست‌ها، یادداشت‌های همگام‌شده، پیام‌ها، نامه‌ها، تاریخچه تماس و metadata رسانه‌ها.
- D1 BLOB chunks: فایل‌ها در قطعات 200 KiB ذخیره می‌شوند. این روش از الزام به ساخت اشتراک R2 دوری می‌کند تا نصب اولیه بتواند روی سهمیهٔ رایگان بماند. در عوض، رسانه‌ها بخشی از سهمیه و فضای D1 را مصرف می‌کنند و دانلود یک فایل بزرگ چند پرس‌وجوی کوچک دارد. این روش برای بار سبک دو نفره طراحی شده است.
- Durable Objects: WebSocket زنده برای پیام، حضور آنلاین، تایپ‌کردن و سیگنال‌دهی تماس.
- GitHub Actions: مخزن GitHub منبع اصلی کد است؛ پس از افزودن یک‌بارهٔ Secrets لازم، هر Push به `main` یا `master` با تغییر کد، migration یا تنظیمات استقرار Cloudflare به‌طور خودکار D1 را ایجاد/بازیابی می‌کند، migrationها را اجرا می‌کند، Worker را منتشر می‌کند و health check می‌زند. اجرای دستی از **Actions → Deploy Big Sister API to Cloudflare → Run workflow** نیز ممکن است.

Cloudflare سهمیه‌های رایگان دارد، اما هیچ سرویس ابری را نمی‌توان بدون قید و شرط برای همیشه رایگان تضمین کرد. عبور از سهمیه‌های روزانه می‌تواند درخواست‌های بیشتر را متوقف کند. این نسخه عمداً به R2 وابسته نیست، چون فعال کردن R2 وارد مرحلهٔ subscription/checkout می‌شود.

## راه‌اندازی یک‌باره (بعد از آن deploy خودکار است)

برای امنیت، اتصال به حساب Cloudflare و افزودن رمزها باید یک بار توسط صاحب حساب انجام شود؛ این گفتگو نباید محل ارسال توکن‌ها یا رمزها باشد. بعد از این تنظیم یک‌باره، انتشار Worker از GitHub Actions خودکار می‌شود.

1. در Cloudflare به <https://dash.cloudflare.com/> برو، حساب درست را انتخاب کن و از صفحهٔ اصلی **Account ID** را کپی کن. لازم نیست D1 را دستی بسازی؛ workflow در صورت نبودن، پایگاه `big-sister-db` را ایجاد می‌کند و در صورت وجود آن را دوباره به کار می‌گیرد.
2. در Cloudflare، **My Profile → API Tokens → Create Token** یک API Token محدود برای این deployment بساز. مجوزهای لازم: **Account Settings: Read**, **Workers Scripts: Edit**, **D1: Read** و **D1: Write**؛ این Worker از `workers.dev` استفاده می‌کند و نیازی به مجوز DNS یا دامنه ندارد. سطح دسترسی را تا حد ممکن به همان Account محدود کن.
3. در GitHub مخزن را باز کن: **Settings → Secrets and variables → Actions → New repository secret**. موارد زیر را با نام دقیق ایجاد کن:
   - `CLOUDFLARE_API_TOKEN` — توکنی که همین الان در Cloudflare ساختی.
   - `CLOUDFLARE_ACCOUNT_ID` — شناسهٔ Account مرحلهٔ ۱.
   - `JWT_SECRET` — رشتهٔ تصادفی قوی با حداقل ۳۲ نویسه.
   - `SHARED_ROOM_KEY` — رشتهٔ تصادفی جداگانه با حداقل ۳۲ نویسه.
   - `LITTLE_BROTHER_PASSWORD` — همان رمز ورود برادر در برنامه.
   - `BIG_SISTER_PASSWORD` — همان رمز ورود خواهر در برنامه. این رمز باید با رمز برادر متفاوت باشد.
4. ذخیره کن و در GitHub وارد **Actions → Deploy Big Sister API to Cloudflare → Run workflow → Run workflow** شو. workflow خودش D1 را می‌سازد/پیدا می‌کند، شناسه را در پیکربندی موقت Runner جایگزین می‌کند، migrationها را اجرا می‌کند، Worker و Durable Object را deploy می‌کند، secrets را تنظیم می‌کند و endpoint سلامت را آزمایش می‌کند. پس از آن، تغییر در کد، migrationها، `cloudflare/package.json`، `cloudflare/wrangler.toml` یا همین workflow در `main` یا `master` deployment خودکار را فعال می‌کند.

در انتها URL معمولاً به شکل `https://big-sister-sync-cloudflare.<SUBDOMAIN>.workers.dev` است. آن را در لاگ اجرای موفق Actions پیدا کن یا از **Cloudflare Dashboard → Workers & Pages → big-sister-sync-cloudflare** بردار. تست سلامت:
`https://<URL-نهایی>/api/health`
باید `"ok":true` و `"provider":"cloudflare-workers"` برگرداند.

> اگر workflow به خطای permission خورد، توکن را از نو با مجوزهای بالا و در همان حسابی که Account ID آن را ثبت کرده‌ای ایجاد کن. مقادیر secret را در Issue، کد، فایل README یا این چت قرار نده. workflow هیچ مقدار حساس را چاپ نمی‌کند.

## اتصال برنامهٔ Flutter

در تنظیمات برنامه، آدرس اصلی Worker را (بدون `/api/health` و بدون مسیر انتهایی) وارد و گزینهٔ تست اتصال را اجرا کن. نمونه:

`https://big-sister-sync-cloudflare.<SUBDOMAIN>.workers.dev`

بهترین راه برای تغییر بدون build مجدد، وارد کردن URL نهایی در بخش تنظیمات برنامه است. در این مخزن در حال حاضر workflow استقرار Cloudflare تعریف شده؛ این workflow APK نمی‌سازد و `BIG_SISTER_API_URL` را به‌صورت خودکار داخل APK قرار نمی‌دهد. اگر از سورس APK جدید بسازی، آدرس API را طبق دستور build موجود تنظیم کن؛ در صورت خالی‌ماندن مقدار، رفتار پیش‌فرض Railway حفظ می‌شود.

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
