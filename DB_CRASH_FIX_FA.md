# رفع مشکل Crash بعد از ساخت PostgreSQL

اگر بعد از اضافه کردن PostgreSQL سرویس Railway خاموش/Restart می‌شد، علت اصلی این بود که Backend قبل از گوش دادن روی PORT، دیتابیس را initialize می‌کرد. اگر DB هنوز آماده نبود یا یکی از Variables ضروری خالی بود، فرآیند Node خاتمه پیدا می‌کرد.

در این نسخه:

- سرور ابتدا روی `PORT` بالا می‌آید.
- اتصال و ساخت schema در پس‌زمینه انجام می‌شود.
- اتصال PostgreSQL تا ۳۰ تلاش، هر ۵ ثانیه، دوباره امتحان می‌شود.
- تا آماده شدن DB، `/api/health` پاسخ `503` می‌دهد.
- بعد از آماده شدن DB، `/api/health` پاسخ `200` می‌دهد.
- نبودن `DATABASE_URL`، `JWT_SECRET`، `ME_PASSWORD` یا `SISTER_PASSWORD` دیگر باعث crash فوری Node نمی‌شود؛ در Logs علت دقیق ثبت می‌شود.

## Variables لازم در API

```text
NODE_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
JWT_SECRET=<secret طولانی و تصادفی>
ME_PASSWORD=<رمز تو>
SISTER_PASSWORD=<رمز خواهرت>
CORS_ORIGIN=*
MEDIA_DIR=/data/media
MAX_UPLOAD_MB=25
ROOM_CODE_TTL_HOURS=24
SHARED_ROOM_KEY=big-sister-private-room
ME_LABEL=من
SISTER_LABEL=آبجی
```

`Postgres` را با **نام واقعی سرویس PostgreSQL در Railway** جایگزین کن.

## Healthcheck

```text
/api/health
```

## تست

وقتی Deploy سالم شد، باز کن:

```text
https://YOUR-RAILWAY-DOMAIN/api/health
```

باید JSON زیر را ببینی:

```json
{
  "ok": true,
  "service": "big-sister-sync"
}
```
