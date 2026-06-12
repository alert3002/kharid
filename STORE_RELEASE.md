# Kharid.tj — нашр қадам ба қадам

**Тартиб:** аввал **Google Play** → баъд **Apple Developer**  
**Application ID / Bundle ID:** `tj.kharid.app`  
**Privacy Policy:** https://kharid.tj/privacy

---

# ҚИСМ A — GOOGLE PLAY (Android)

## Қадами 1 — Ҳисоби Google Play Developer

1. Ба [Google Play Console](https://play.google.com/console) ворид шавед.
2. Агар ҳисоби developer надоред — **Регистрация** ($25 як маротиба).
3. Профилро пур кунед (ном, суроға, телефон).

---

## Қадами 2 — `key.properties` ва keystore (имзои release)

Ин **як маротиба** аст. Бе ин Google Play AAB-и release қабул намекунад.

### Вариант A — скрипт (Windows, тавсия)

```powershell
cd C:\Users\ALIJOn\Desktop\kharid.tj\app
.\scripts\setup-play-signing.ps1
```

Скрипт мепурсад:
- пароли keystore
- номи ширкат

Месозад:
- `android/upload-keystore.jks`
- `android/key.properties`

### Вариант B — дастӣ

```powershell
cd C:\Users\ALIJOn\Desktop\kharid.tj\app\android
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload -keystore upload-keystore.jks
```

Пас `key.properties.example`-ро нусха баред → `key.properties`:

```properties
storePassword=ПАРОЛИ_ШУМО
keyPassword=ПАРОЛИ_ШУМО
keyAlias=upload
storeFile=../upload-keystore.jks
```

| Майдон | Маъно |
|--------|--------|
| `storePassword` | Пароли файли `.jks` |
| `keyPassword` | Пароли кунҷи `upload` (одатан ҳамон) |
| `keyAlias` | Ҳамеша `upload` |
| `storeFile` | Роҳ ба keystore аз `android/app/` → `../upload-keystore.jks` |

> ⚠️ **upload-keystore.jks** ва паролҳоро дар ҷои бехатар нигоҳ доред (Google Drive + парол ё флешка). Агар гум шавад — навсозии барнома дар Play ғайриимкон мешавад.

---

## Қадами 3 — Санҷиши имзо

```powershell
cd C:\Users\ALIJOn\Desktop\kharid.tj\app
flutter pub get
flutter build appbundle --release
```

Агар муваффақ шуд:

```
build\app\outputs\bundle\release\app-release.aab
```

Агар хатогӣ оид ба `key.properties` — санҷед, ки файл дар `app\android\key.properties` аст.

---

## Қадами 4 — Барнома дар Play Console

1. Play Console → **Create app**
2. Ном: **kharid.tj**
3. Default language: Russian ё English
4. App / Game: **App**
5. Free / Paid: **Free**
6. Тасдиқи сиёсатҳо → **Create app**

---

## Қадами 5 — Dashboard — вазифаҳои зарурӣ

Play Console ҳар вазифаро нишон медиҳад. Пур кунед:

### 5.1 App access
- Агар барнома бе login кор кунад → **All functionality is available without restrictions**
- Агар login лозим → дастурҳои тест (телефон + OTP) диҳед

### 5.2 Ads
- **No, my app does not contain ads** (агар реклама нест)

### 5.3 Content rating
- Анкетаи **IARC** → категория Shopping → натиҷаро гиред

### 5.4 Target audience
- Синну сол: **18+** ё **13+** (маркетплейс одатан 18+)

### 5.5 News app
- **No**

### 5.6 COVID-19 / Government apps
- **No**

### 5.7 Data safety
Маълумоте, ки ҷамъ мешавад (мувофиқи `/privacy`):

| Навъ | Ҳа |
|------|-----|
| Phone number | ✓ (вход OTP) |
| Name, address | ✓ (профил/заказ) |
| Photos | ✓ (аватар, товар продавца) |
| Location | ✓ (курьер/доставка, иҷозат) |
| App activity (orders) | ✓ |
| Device IDs | ✓ (технические) |

- Data encrypted in transit: **Yes** (HTTPS)
- Users can request deletion: **Yes** → info@kharid.tj

### 5.8 Privacy policy
URL: **https://kharid.tj/privacy**

---

## Қадами 6 — Store listing (саҳифаи мағоза)

**Main store listing:**

| Майдон | Маълумот |
|--------|----------|
| App name | kharid.tj |
| Short description (80) | Маркетплейс Таджикистана: товары, доставка, бонусы |
| Full description (4000) | Тавсифи пурра оид ба харид, фурӯш, MLM, доставка |
| App icon | `app/assets/logo512.png` (512×512 PNG) |
| Feature graphic | 1024×500 баннер |
| Phone screenshots | ҳадди ақал **2** скриншот телефон (1080×1920 ё зиёд) |

**Contact:**
- Email: info@kharid.tj
- Phone: +992 93 988 88 83
- Website: https://kharid.tj

---

## Қадами 7 — Upload AAB

1. **Release** → **Testing** → **Internal testing** (аввал инро тавсия мекунем)
2. **Create new release**
3. Upload: `app-release.aab`
4. Release name: `1.0.0 (1)`
5. Release notes: «Первая версия маркетплейса kharid.tj»
6. **Save** → **Review release** → **Start rollout**

---

## Қадами 8 — Тест internal testing

1. **Testers** → рӯйхати email-ҳои Google илова кунед
2. Линки тестро кушоед дар телефони Android
3. Санҷед: вход OTP, каталог, корзина, Reels, API

---

## Қадами 9 — Production

Пас аз тест:
1. **Release** → **Production** → **Create new release**
2. Ҳамон AAB (ё нав бо versionCode+1)
3. **Send for review**
4. Интизор шавед 1–7 рӯз (одатан)

---

# ҚИСМ B — APPLE DEVELOPER (iOS)

> ⚠️ IPA танҳо дар **Mac** бо **Xcode** сохта мешавад.

## Қадами 10 — Apple Developer Program

1. [developer.apple.com](https://developer.apple.com) → **Account**
2. **Enroll** → Apple Developer Program (**$99/сол**)
3. Ширкат ё шахси воқеӣ — пур кардани маълумот
4. Интизор шавед тасдиқ (1–2 рӯз)

---

## Қадами 11 — App ID дар Developer Portal

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. **Identifiers** → **+** → **App IDs** → **App**
3. Description: `Kharid.tj`
4. Bundle ID: **Explicit** → `tj.kharid.app`
5. Capabilities: ҳозир чизи иловагӣ лозим нест
6. **Register**

---

## Қадами 12 — App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Platforms: **iOS** (танҳо)
4. Name: **kharid.tj**
5. Primary language: Russian
6. Bundle ID: `tj.kharid.app`
7. SKU: `kharid-tj-app` (ҳар чиз уникал)
8. User Access: Full Access

> **iPad интихоб НАКУНЕД** — барнома танҳо iPhone аст.

---

## Қадами 13 — Подпись дар Xcode (Mac)

```bash
cd app
flutter pub get
open ios/Runner.xcworkspace
```

Xcode → **Runner** (target) → **Signing & Capabilities**:
- Team: ҳисоби Apple Developer-и шумо
- Bundle Identifier: `tj.kharid.app`
- ✅ Automatically manage signing

---

## Қадами 14 — Сборка IPA

```bash
cd app
flutter build ipa --release
```

Файл: `build/ios/ipa/*.ipa`

Ё дар Xcode: **Product** → **Archive** → **Distribute App** → **App Store Connect**

---

## Қадами 15 — Метаданные App Store

Дар App Store Connect → барномаи kharid.tj:

| Майдон | Қимат |
|--------|-------|
| Privacy Policy URL | https://kharid.tj/privacy |
| Category | Shopping |
| Screenshots | iPhone 6.7" (мин. 1), тавсия 6.5" ҳам |
| Description | Монанди Play |
| Keywords | маркетплейс, таджикистан, kharid, покупки |
| Support URL | https://kharid.tj/contacts |
| Marketing URL | https://kharid.tj |

### App Privacy (ҳамон Data safety)
- Phone Number, Location, Photos, Purchase History — мувофиқ `/privacy`

### Export Compliance
- Uses encryption? → **Yes** (HTTPS)
- Exempt? → **Yes** — танҳо стандартии HTTPS (`ITSAppUsesNonExemptEncryption = false` дар Info.plist)

---

## Қадами 16 — TestFlight

1. Build-ро upload кунед (аз Xcode ё `flutter build ipa`)
2. **TestFlight** → Internal Testing → тестерҳо илова кунед
3. Дар iPhone тест кунед

---

## Қадами 17 — Submit for Review

1. **App Store** → версияи 1.0.0
2. Build интихоб кунед
3. **Submit for Review**
4. Интизор шавед 1–3 рӯз (одатан)

---

# Навсозии баъдӣ

Дар `app/pubspec.yaml`:

```yaml
version: 1.0.1+2   # ном + build number
```

```powershell
# Android
flutter build appbundle --release --build-name=1.0.1 --build-number=2

# iOS (Mac)
flutter build ipa --release --build-name=1.0.1 --build-number=2
```

---

# Чеклист зуд

### Google Play
- [ ] `android/key.properties` сохта шуд
- [ ] `android/upload-keystore.jks` нигоҳ дошта шуд
- [ ] `flutter build appbundle --release` муваффақ
- [ ] Play Console: Data safety + Privacy URL
- [ ] AAB upload → Internal test → Production

### Apple
- [ ] Developer Program фаъол
- [ ] Bundle ID `tj.kharid.app`
- [ ] iPad **нест**
- [ ] IPA upload → TestFlight → Review
- [ ] Privacy URL: https://kharid.tj/privacy
