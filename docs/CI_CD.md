# CI/CD: GitHub Actions + Fastlane + Firebase App Distribution

## Пайплайн

```
PR / push в main
  └─ checks (ubuntu)            dart format → flutter analyze → flutter test --coverage
       └─ android (ubuntu)      flutter build apk --release (номер билда = run_number)
            ├─ artifact          APK доступен в прогоне для любого PR
            └─ fastlane          только push в main → Firebase App Distribution, группа testers

nightly 02:00 UTC / вручную
  └─ integration (emulator)     flutter test integration_test на Android API 34
```

| Файл | Что делает |
|---|---|
| `.github/workflows/ci.yml` | CI на каждый PR, CD на push в `main` |
| `.github/workflows/integration.yml` | integration-тесты на эмуляторе (ночью и по кнопке) |
| `android/fastlane/Fastfile` | lane `distribute` → `firebase_app_distribution` |
| `android/Gemfile`, `android/fastlane/Pluginfile` | fastlane + плагин, версии через Bundler |
| `android/app/build.gradle.kts` | release-подпись из `android/key.properties`, иначе debug-ключ |

Решения:
- **Flutter закреплён** (`FLUTTER_VERSION: 3.38.0`) — сборка воспроизводима, обновление осознанное.
- **`page_width: 100`** в `analysis_options.yaml` — формат одинаковый у IDE, локально и в CI.
- **Integration-тесты не на каждый PR** — эмулятор медленный (~10 мин), а цифры кадров на нём
  нерепрезентативны; ночной прогон ловит поломки сценариев, реальные замеры — `flutter drive --profile` на устройстве.
- **Обфускация** (`--obfuscate --split-debug-info`) — символы в `build/symbols`; для Crashlytics их надо загружать.
- **Без секретов пайплайн не падает**: подпись → debug-ключ, шаг дистрибуции пропускается.

## Настройка (один раз)

### 1. Firebase
1. [console.firebase.google.com](https://console.firebase.google.com) → создать проект → добавить Android-приложение
   с package `com.example.shaders_and_render_object`.
2. App Distribution → Testers & Groups → группа с alias **`testers`**, добавить почты.
3. Project settings → General → скопировать **App ID** (`1:…:android:…`).
4. Google Cloud Console → IAM → Service Accounts → создать аккаунт с ролью
   **Firebase App Distribution Admin** → Keys → Add key → JSON.

### 2. Release-ключ (опционально, для App Distribution хватает debug-подписи)
```bash
keytool -genkeypair -v -keystore release.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -i release.jks | pbcopy   # → секрет ANDROID_KEYSTORE_BASE64
```

### 3. GitHub → Settings → Secrets and variables → Actions

| Секрет | Значение |
|---|---|
| `FIREBASE_APP_ID` | App ID из шага 1.3 |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | содержимое JSON-ключа из шага 1.4 |
| `ANDROID_KEYSTORE_BASE64` | keystore в base64 (опционально) |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | от keystore (опционально) |

## Локальный запуск дистрибуции
```bash
flutter build apk --release
cd android && bundle install
FIREBASE_APP_ID=1:...:android:... \
FIREBASE_SERVICE_CREDENTIALS_FILE=/path/to/sa.json \
  bundle exec fastlane distribute
```

## Что дальше
- iOS: `fastlane match` (сертификаты в приватном репо) → `gym` → TestFlight / App Distribution, macOS-раннер.
- Flavors dev/stage/prod с разными Firebase-приложениями.
- Загрузка `build/symbols` в Crashlytics, уведомление в Slack/Telegram.
- Tag `v*` → релизная lane в Google Play internal track (`supply`).
