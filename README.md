# CampusApp

Flutter student app for MPEI.

## Local backend and schedule (Windows / PowerShell)

The schedule is served by the separate NestJS repository
`Agarych-ilya/Campus-backend` (branch `feature/cloud`).
Start that backend in a separate terminal before launching the app:

```powershell
# In the Campus-backend directory:
git switch feature/cloud
git pull --ff-only origin feature/cloud
npm install
npm run start:dev
```

Check the backend from Windows:

```powershell
curl.exe http://localhost:8000/health
```

For Android Emulator the PC is accessible as **10.0.2.2**.
Run Flutter from the CampusApp directory:

```powershell
flutter run -d emulator-5554 --dart-define=CAMPUS_API_BASE_URL=http://10.0.2.2:8000
```

For a physical phone use the PC's actual IPv4 address on the same Wi-Fi
network, e.g.:

```powershell
ipconfig
flutter run -d <phone_id> --dart-define=CAMPUS_API_BASE_URL=http://192.168.1.5:8000
```

Replace `192.168.1.5` with your PC's current IPv4 address.
Without `CAMPUS_API_BASE_URL`, the schedule screen checks the former LAN
address first, then the Android Emulator bridge (`10.0.2.2`).
Other services use the explicitly configured URL or the LAN default.

The schedule calls `GET /schedule?group=<group>&date=YYYY-MM-DD`.
The group is provided by the BARS login flow. A fake demo group is no
longer inserted when no BARS group is available. The mobile app caches
successful weekly results and displays cached lessons with an offline
warning if the server is down.

If the API responds but the MPEI schedule cannot be fetched, check the
backend logs and the upstream RUZ service. The mobile app cannot load
live schedules until the backend is reachable.


## Сообщества студентов

Экран **Сервисы → Группы** получает каталог из
`GET /services/groups` и показывает карточки, описания, ссылки на
Telegram/ВКонтакте, поиск и фильтры. Если связь с бэкендом пропала,
остаются встроенные группы, но счётчик будет недоступен.

**Добавить сообщество:** название, описание, категория, ссылки TG/VK,
а также **собственное изображение, выбираемое из галереи**. Фото
автоматически обрезается до квадрата 400×400 и сжимается в JPEG
перед загрузкой через `multipart/form-data`. Картинка сохраняется на
бэкенде; после проверки сообщество показывается всем студентам
с выбранной иконкой. Пока заявка `pending`, её изображение и
карточка сохраняются локально на устройстве автора.

**Количество участников пользователь не вводит.** Сервер пытается
считать его с публичной страницы Telegram (или через Bot API, если
настроен `TELEGRAM_BOT_TOKEN`). Для ВКонтакте сервер использует
`VK_ACCESS_TOKEN` в локальном `.env`; токен Flutter не получает.
Численность кешируется на сервере на 15 минут, источник и время
проверки указываются в карточке. Если сервис не отдал число,
показывается «Нет данных об участниках». У сокращённых
счётчиков Telegram (`12.1K`) ставится знак приблизительности `≈`.

Для работы этих функций **обязательно** обнови и запусти бэкенд
`Agarych-ilya/Campus-backend` из ветки `feature/cloud`.
На реальном телефоне по USB на Windows используется ADB Reverse:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s AM5HJV5A09H00643 reverse tcp:8000 tcp:8000
flutter run -d AM5HJV5A09H00643 --dart-define=CAMPUS_API_BASE_URL=http://127.0.0.1:8000
```

Тесты модели:

```powershell
flutter test test/features/services/community_data_test.dart
```

## Администрирование сообществ

В разделе **Сервисы → Группы** появилась кнопка со значком
администратора. Она открывает защищённую панель модерации.

- **На проверке**: подтверждение, отклонение и удаление заявки.
- **Опубликованы**: изменение текста, категории, ссылок Telegram/VK,
  собственной фотографии и резервного значка; удаление.
- **Скрытые**: стартовые сообщества после удаления скрываются
  на сервере, их можно восстановить.
- **Отклонены**: просмотр, редактирование и окончательное удаление.

Авторизация администратора **не связана** с БАРС: учебный
профиль МЭИ сохраняется в телефоне и не подтверждает роль серверу.
Администратор входит отдельно по **логину Campus-backend и паролю**,
например `OgarkovIA`.

Для назначения прав **не нужно искать ID пользователя в MySQL**:
сначала зарегистрируй уникальный аккаунт `OgarkovIA` через
`POST /auth/register`, затем добавь в локальный `.env` бэкенда:

```dotenv
COMMUNITY_ADMIN_USERNAMES=OgarkovIA
SESSION_SECRET=ДЛИННАЯ_СЛУЧАЙНАЯ_СТРОКА_ОТ_32_СИМВОЛОВ
```

Важен порядок: при настроенной админ-роли публичная регистрация
зарезервированного имени запрещена. Если аккаунт уже зарегистрирован,
повторно создавать его не нужно.

Email требуется только для первоначальной регистрации в бэкенде.
**В админ-панели проверяются логин и пароль**, после чего сервер
проверяет имя по разрешённому списку. Введённый без пароля логин
администраторских прав не даёт. Полная инструкция находится в README
бэкенда в ветке `feature/cloud`.

Для Android по USB проверь `adb reverse tcp:8000 tcp:8000`
и запускай Flutter с параметром
`--dart-define=CAMPUS_API_BASE_URL=http://127.0.0.1:8000`.

Когда бэкенд временно недоступен, показывается последний сохранённый
публичный каталог (а не старый жёстко заданный список групп),
чтобы скрытые администратором сообщества не появлялись повторно.
Заявки текущего устройства по-прежнему сохраняются локально, пока
их не рассмотрели или не удалили через админ-панель.

