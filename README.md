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
`GET /services/groups` и показывает карточки с уникальными цветными
иконками, описанием, численностью и ссылками на Telegram/ВКонтакте.
Есть поиск и фильтры по категориям. По нажатию открывается подробная
карточка сообщества, а ссылки — только по нажатию кнопки.

Кнопка **Добавить** открывает форму: название, описание, категория,
иконка, необязательное количество участников и ссылки Telegram/VK.
После успешного запроса `POST /services/groups/submissions` группа
показывается автору со статусом **На проверке**. Локальная карточка
сохраняется между перезапусками устройства и исчезает из заявок,
когда появляется в публичном каталоге. При недоступном бэкенде
остаётся встроенный список уже известных сообществ, но новые заявки
на сервер отправить нельзя.

Количество подписчиков у некоторых встроенных Telegram-каналов —
снимок открытых страниц за октябрь 2026 года. Это не подсчёт
студентов и не автоматическая live-статистика. Для добавляемых групп
число участников указывается автором и помечается как непроверенное.
Иконки — локальные авторские стилизованные пиктограммы, а не
официальные аватарки сообществ.

Тесты модели каталога:

```powershell
flutter test test/features/services/community_data_test.dart
```

