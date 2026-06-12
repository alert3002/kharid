# Google Play — «Demo version» / App access

Play Console дар **App content → App access** мепурсад, ки чӣ гуна барномаро санҷанд.

## 1. Интихоб кунед

**Some or all functionality is restricted**  
(«Қисми функсияҳо бо воридшавӣ маҳдуд аст»)

---

## 2. Матнро нусха кунед (Instructions for reviewers)

```
Kharid.tj is a marketplace app. Catalog and product pages work without login.
Login is required for cart, checkout, profile, seller/courier features.

TEST LOGIN (no real SMS needed):

1. Open the app or website login
2. Phone (9 digits, without +992): 90 000 00 01
   (full number: 992900000001)
3. Tap "Get code" / request OTP
4. Enter OTP code: 4242
5. Complete registration if prompted (any name/city is OK for review)

IMPORTANT: Do not use a real phone (e.g. 93 988 88 83). Only 90 000 00 01 works with code 4242.

The test account uses a fixed OTP on our server for Google Play review only.

API: https://api.kharid.tj
Privacy: https://kharid.tj/privacy

If login fails, contact: info@kharid.tj / +992 93 988 88 83
```

---

## 3. Дар сервер илова кунед (.env)

Пеш аз review инро дар `api.kharid.tj` `.env` гузоред ва backend-ро restart кунед:

```env
PLAY_STORE_REVIEW_PHONE=900000001
PLAY_STORE_REVIEW_OTP=4242
```

Санҷиш:

```bash
curl -X POST https://api.kharid.tj/api/v1/auth/phone/request/ \
  -H "Content-Type: application/json" \
  -d '{"phone":"900000001"}'
# → {"status":"ok", ...}  (без SMS)

curl -X POST https://api.kharid.tj/api/v1/auth/phone/verify/ \
  -H "Content-Type: application/json" \
  -d '{"phone":"900000001","code":"4242"}'
```

---

## 4. Бе login чӣ кор мекунад

Барои reviewers, ки ворид намешаванд:

- **Главная** — каталог, баннерҳо
- **Каталог** — рӯйхати товарҳо
- **Reels** — видео (агар бошад)

**Корзина / профил** — login лозим (demo-аккаунт дар боло).

---

## 5. Demo video (агар пурсанд)

Play баъзан **видео** мехоҳад. 30–60 сония экран:

1. Кушодани барнома
2. Гаштан дар каталог
3. Воридшавӣ бо `900000001` / `4242`
4. Корзина

Запис экрана телефон → upload дар Store listing.

---

## 6. Apple App Store (ҳамон аккаунт)

Дар **App Review Information** → **Notes**:

```
Test phone: 900000001
OTP code: 4242 (fixed for review, no SMS)
Privacy: https://kharid.tj/privacy
```
