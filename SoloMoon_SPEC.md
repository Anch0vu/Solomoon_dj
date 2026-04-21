# SoloMoon's Club — ТЗ

> Виртуальный ночной клуб для ролевого сервера OctothorpTeam (Garry's Mod, Новый Доброград).
> Радиостанция 24/7 с возможностью live DJ-сетов через веб-пульт.

---

## 1. Контекст и цели

### Внешний контекст
- Сервер OctothorpTeam — чужой, аддон туда не ставим.
- Игроки слушают радио через клиентский интерфейс OT (стандартный аддон со списком одобренных станций).
- Чтобы попасть в этот список — нужно одобрение по [требованиям OT](https://forum.octothorp.team/topic/10/).

### Требования OT (критично)
1. Единый стиль, треки в тему.
2. Заявка содержит: описание + жанр + ссылку на поток + ссылку на плейлист.
3. Плейлист ≥ 120 минут, заранее.
4. Круглосуточная работа.
5. Хостинг оплачен минимум на месяц.

### Главные сценарии использования
1. **24/7 fallback** — на ссылке всегда что-то играет (House/EDM/R&B плейлист в коктейльной атмосфере).
2. **Live DJ-сет** — у Anch0vu или модератора открыт веб-пульт, он крутит сет в реалтайме, заменяя fallback. Используется для отыгрышей "ночь в клубе" в gmod.
3. **Внешнее прослушивание** — кто-то заходит на solomoon-club.tld, видит лого, плеер, текущий статус ("LIVE сейчас" / "Auto-mix"), может слушать прямо в браузере.

---

## 2. Архитектура

```
┌──────────────────────────────────────────────────────────────────────┐
│  WINDOWS SERVER 2022 (Politota Team, Москва)                         │
│  Docker Engine                                                       │
│                                                                      │
│  ┌─────────────────┐                                                 │
│  │  fallback.mp3   │  папка с курируемой музыкой                     │
│  │  /music/...     │  (House/EDM/R&B)                                │
│  └────────┬────────┘                                                 │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────────────┐                                         │
│  │  liquidsoap             │   приоритет:                            │
│  │  switch:                │   1) live (если активен)                │
│  │   • input.harbor :8005  │◄──┐  → перебивает fallback              │
│  │   • playlist (rotate)   │   │                                     │
│  │  → crossfade            │   │                                     │
│  │  → normalize (ReplayGain)│  │                                     │
│  │  → output.icecast       │   │                                     │
│  └────────────┬────────────┘   │                                     │
│               │                │                                     │
│               ▼                │ source push (mp3 от ffmpeg)         │
│  ┌─────────────────────────┐   │                                     │
│  │  Icecast2 :8000         │   │                                     │
│  │  /stream.mp3 (главное)  │◄──┘                                     │
│  │  /status-json.xsl       │                                         │
│  └────────────┬────────────┘                                         │
│               │                                                      │
│               │ публичная ссылка для OT и для всех                   │
│               ▼                                                      │
│  ┌─────────────────────────┐                                         │
│  │  radio-api (Node)       │   • WS endpoint для DJ-деки             │
│  │  :8080                  │   • прокси к Navidrome (browse)         │
│  │  • express + ws         │   • /nowplaying (читает Icecast JSON)   │
│  │  • spawn ffmpeg для     │   • простая auth (токен)                │
│  │    каждого DJ-коннекта  │                                         │
│  └────────────┬────────────┘                                         │
│               │                                                      │
│               │ WebM/Opus от браузера → ffmpeg → mp3 → harbor:8005   │
│               │                                                      │
│  ┌─────────────────────────┐                                         │
│  │  Navidrome :4533        │   медиабиблиотека (Subsonic API)        │
│  │  индексирует /music/    │   опционально, можно без неё            │
│  └─────────────────────────┘                                         │
│                                                                      │
│  ┌─────────────────────────┐                                         │
│  │  nginx :80/:443         │   reverse-proxy:                        │
│  │  + Caddy (TLS)          │   • solomoon-club.tld → web-app         │
│  │                         │   • api.solomoon-club.tld → radio-api   │
│  │                         │   • dj.solomoon-club.tld → DJ-deck      │
│  │                         │   • stream.mp3 остаётся на :8000        │
│  └─────────────────────────┘                                         │
└──────────────────────────────────────────────────────────────────────┘
                ▲                          ▲                  ▲
                │ браузер                  │ браузер          │ HTTP
                │                          │                  │
       ┌────────┴────────┐       ┌─────────┴────────┐  ┌──────┴────────┐
       │  DJ-пульт       │       │  Веб-сайт клуба  │  │ gmod-клиент   │
       │  (React app)    │       │  (React static)  │  │ sound.PlayURL │
       │  только Anch0vu │       │  публичный       │  │ через OT-меню │
       │  + модераторы   │       │  лендинг + плеер │  │               │
       └─────────────────┘       └──────────────────┘  └───────────────┘
```

### Поток данных в трёх режимах

**Режим A: Auto-mix (fallback).**
fallback playlist → liquidsoap → Icecast → слушатели. Всё работает без участия человека, 24/7.

**Режим B: Live DJ.**
Браузер с DJ-пультом микширует две деки + сэмплы → MediaRecorder → WebSocket → radio-api → ffmpeg → liquidsoap input.harbor:8005. Liquidsoap видит активный harbor-вход и переключается на него (fallback на паузе). Вышел из эфира — fallback возвращается.

**Режим C: Веб-сайт.**
Статика, в `<audio>` тег зашит `http://stream.solomoon-club.tld:8000/stream.mp3`. Раз в 10 секунд опрашивает `/api/nowplaying`, показывает либо "🔴 LIVE — SoloMoon", либо "Auto-mix · Artist — Track".

---

## 3. Стек

| Компонент | Технология | Обоснование |
|---|---|---|
| Стриминг-сервер | **Icecast 2.4** | стандарт индустрии, gmod ест mp3 без вопросов |
| Микшер | **Liquidsoap 2.2+** | switch + crossfade + harbor-вход в 30 строк конфига |
| Бэкенд | **Node 20 + TypeScript** + express + ws | один процесс, простой деплой |
| Перекодер | **ffmpeg** (spawn из Node) | webm/opus → mp3 для liquidsoap |
| DJ-пульт | **React 18 + Vite + TypeScript** | компонентный UI, легко растить |
| Аудио-движок | **Web Audio API** + **wavesurfer.js v7** + **Tone.js** (для сэмплера) | wavesurfer = waveform/regions для hot-cues |
| BPM | **realtime-bpm-analyzer** или **web-audio-beat-detector** | offline-анализ при загрузке трека |
| Веб-сайт | **React + Vite** (статика) | один Vite-конфиг на оба фронта |
| Медиатека | **Navidrome** (опц.) | Subsonic API → browse из деки |
| Реверс-прокси | **Caddy** | автоматический Let's Encrypt |
| Контейнеризация | **Docker Compose** | один `docker compose up` |

### Что НЕ используется и почему
- **AzuraCast** — слишком монолитный, тащит свой UI/auth/DB, не вписывается в кастомный DJ-пульт.
- **Tauri/Electron** — не нужен desktop, браузер всё умеет.
- **Vue/Svelte** — оставляем React, у тебя уже есть опыт.
- **Mixxx** — десктоп-приложение, не отдаёт поток в Icecast без танцев.
- **Gmod-аддон** — сервер чужой, не вариант.

---

## 4. DJ-пульт — фичи v1

### Деки (×2)
- Загрузка: drag&drop файл / URL / browse Navidrome.
- Waveform с курсором проигрывания, кликабельный.
- PLAY/PAUSE, CUE (вернуться к hot-cue 0).
- Gain (0..1.5), Rate (0.5..1.5×, отображается в %).
- 3-полосный EQ: HI shelf / MID peaking / LO shelf.
- 8 hot-cues: установить (`SHIFT+1..8`), прыгнуть (`1..8`). Quantize on/off.

### Микшер
- Crossfader equal-power.
- Master volume + 2-канальный VU-meter.
- LIVE индикатор / GO LIVE кнопка (запуск стрима в radio-api).

### BPM/sync
- При загрузке трека — offline-анализ (web-worker, не блокирует UI).
- BPM показывается на деке.
- Кнопка SYNC: подгоняет rate деки B под BPM деки A.
- Beatgrid накладывается на waveform.

### Sampler bank
- 8 ячеек, в каждую можно положить mp3 (drag&drop).
- Trigger по hotkey (`Q W E R T Y U I` по умолчанию).
- Quantize triggering к доле (если включён в hot-cues).
- Preset для SoloMoon: набор jingle'ов "Welcome to SoloMoon", "DJ on air", дропы.

### Library panel
- Если Navidrome подключён — список треков, поиск, drag в деку.
- Если нет — просто инпут URL и история последних загруженных.

---

## 5. Брендинг SoloMoon's Club

### Идентичность
- **Имя:** SoloMoon's Club
- **Слоган-кандидаты** (выбрать или дать варианты):
  - "Where the city sleeps, we wake up."
  - "Members only. Every night."
  - "By invitation. Always loud."
- **Концепция:** закрытый коктейльный клуб в Доброграде. Эксклюзивность, ночь, дорогая выпивка, House/Deep House/EDM/R&B. Не "массовый" клуб — место "своих".

### Палитра (предложение)
- Фон: глубокий полночный синий `#0B0E1A`
- Основа: тёплый кремовый `#F0E6D2` (как свет настольных ламп)
- Акцент 1: лунный персиковый `#FFB17A`
- Акцент 2: глубокий бордо `#5C1E2E` (винные тона)
- Подсветка: холодный лунный `#A8C5E0`

### Типографика
- Display: **Cormorant Garamond** или **Playfair Display** (богатый serif для лого/заголовков)
- UI: **JetBrains Mono** (на DJ-пульте) / **Inter Tight** (на сайте клуба, опц.)

### Лого
SVG, два состояния:
- Полное: серп луны + текст "SoloMoon's Club" + год основания
- Минималка: только серп для favicon/иконок

### Описание для заявки в OT (черновик)
> **SoloMoon's Club** — ночное радио в эфире кокетльного клуба Доброграда. Здесь играют House, Deep House, EDM и R&B — музыка, под которую разговаривают за барной стойкой и танцуют до утра. Эфир работает круглосуточно в режиме автоматической ротации, с регулярными живыми DJ-сетами по выходным.
>
> Жанры: House, Deep House, EDM, R&B
> Поток: http://stream.solomoon-club.tld:8000/stream.mp3
> Плейлист: https://solomoon-club.tld/playlist

---

## 6. Структура репо

```
solomoon-club/
├── docker-compose.yml
├── .env.example
├── README.md
│
├── liquidsoap/
│   └── radio.liq
│
├── icecast/
│   └── icecast.xml
│
├── caddy/
│   └── Caddyfile
│
├── radio-api/                  # Node бэкенд
│   ├── src/
│   │   ├── index.ts
│   │   ├── ws-bridge.ts        # WS → ffmpeg → liquidsoap harbor
│   │   ├── nowplaying.ts       # парсит Icecast status-json
│   │   ├── navidrome.ts        # прокси Subsonic API
│   │   └── auth.ts             # bearer-token
│   ├── package.json
│   └── tsconfig.json
│
├── deck/                       # DJ-пульт (React + Vite)
│   ├── src/
│   │   ├── audio/
│   │   │   ├── engine.ts
│   │   │   ├── deck.ts
│   │   │   ├── sampler.ts
│   │   │   ├── beatgrid.ts
│   │   │   └── streamer.ts
│   │   ├── ui/
│   │   │   ├── Deck.tsx
│   │   │   ├── Mixer.tsx
│   │   │   ├── Sampler.tsx
│   │   │   ├── Library.tsx
│   │   │   ├── Waveform.tsx
│   │   │   └── BroadcastBar.tsx
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── index.html
│   ├── package.json
│   └── vite.config.ts
│
├── club-site/                  # Публичный сайт SoloMoon's Club
│   ├── src/
│   │   ├── components/
│   │   │   ├── Hero.tsx
│   │   │   ├── Player.tsx
│   │   │   ├── NowPlaying.tsx
│   │   │   ├── Playlist.tsx
│   │   │   └── Footer.tsx
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── public/
│   │   ├── logo.svg
│   │   └── og.png
│   ├── index.html
│   ├── package.json
│   └── vite.config.ts
│
├── brand/                      # Бренд-пак
│   ├── logo-full.svg
│   ├── logo-mark.svg
│   ├── tokens.css              # CSS-переменные с палитрой
│   └── README.md               # bran guidelines
│
└── music/                      # ⚠️ НЕ В РЕПО, только локально
    └── (твой плейлист 120+ минут)
```

---

## 7. План работ (фазы)

### Фаза 0 — Подготовка (твоя работа, до кода)
- Подобрать минимум 120 минут музыки по жанрам, сложить в `music/`.
- Решить, есть ли у тебя домен (или будем работать по IP до получения).
- Поставить Docker Engine на Windows Server 2022, если ещё нет.

### Фаза 1 — Радио 24/7 (вечер)
- docker-compose: Icecast + Liquidsoap + Caddy.
- Liquidsoap: playlist режим из `/music/`, crossfade 4s, ReplayGain.
- Тест: открыть `http://server:8000/stream.mp3` в VLC — должно играть.
- Вердикт: можно подавать заявку в OT (хотя стрим без бренда).

### Фаза 2 — Бренд + сайт клуба (вечер)
- SVG-лого (2 варианта).
- `tokens.css` с палитрой/типографикой.
- React-сайт: hero с лого, плеер, NowPlaying, Playlist (статичный список из 120 минут).
- Каста на `solomoon-club.tld` через Caddy.
- Финализовать описание/слоган.
- Подавать заявку в OT.

### Фаза 3 — Live режим (1-2 вечера)
- Liquidsoap: добавить `input.harbor` с приоритетом над playlist.
- radio-api: WS-bridge → ffmpeg → harbor.
- DJ-пульт v1: 2 деки, EQ, crossfader, GO LIVE. Без BPM/cues пока.
- Тест: подключиться к DJ-пульту, GO LIVE, проверить что Icecast переключился.

### Фаза 4 — DJ-фичи (1-2 вечера)
- BPM-анализ + beatgrid + sync.
- Hot-cues (8 на деку, quantize).
- Sampler bank (8 ячеек, hotkey trigger).
- Library panel (Navidrome или хотя бы URL-history).

### Фаза 5 — Полировка
- "🔴 LIVE" индикатор на сайте клуба.
- ICY-метаданные ("SoloMoon Live" в названии стрима).
- Запись эфиров на диск (опционально).
- Authentication для DJ-пульта (модераторам выдаётся токен).

---

## 8. Открытые вопросы / риски

1. **Домен.** Нужен ли он сейчас? Без домена можно крутить по IP (`http://1.2.3.4:8000/stream.mp3`), OT не запрещает.
2. **Лицензии.** Если контент копирайтный — теоретически проблема, но это твоя зона ответственности и формально OT её не проверяет.
3. **Latency.** Цепочка `браузер → ffmpeg → liquidsoap → icecast → клиент` даст ~5–10 секунд. Для DJ-сета это норма, для микрофона-говорения "ведущий ↔ игрок" — нет.
4. **Полоса.** 192 kbps mp3 × N слушателей. На 50 одновременных — ~1.2 MB/s. У тебя физический сервер в Москве, это не проблема.
5. **Failover.** Если liquidsoap упадёт, упадёт всё. Можно поставить `restart: unless-stopped` в compose, но настоящий failover (резервный сервер) — out of scope.

---

## 9. Что делаем дальше

Жду твоей отмашки на одну из:
- **A.** Делать фазу 1 (24/7 радио в docker-compose), всё остальное потом.
- **B.** Делать фазу 1 + 2 одновременно (радио + сайт + бренд), чтобы заявка в OT была сразу полноценной.
- **C.** Сначала бренд (фаза 2), потом инфраструктура.
- **D.** Дай ещё подумать / уточнить что-то по этому ТЗ.
