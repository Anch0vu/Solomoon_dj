# SoloMoon's Club — Phase 1 (24/7 radio)

24/7 fallback-плейлист в Icecast. Прямая ссылка для заявки в OctothorpTeam.

**Stack:** Icecast2 + Liquidsoap, всё в Docker. Latency ~2–3 сек до клиента.

---

## 1. Подготовка сервера (Ubuntu 24.04)

```bash
# Docker (если не стоит)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Открыть порт 8000 в фаерволе
sudo ufw allow 8000/tcp comment "Icecast"
sudo ufw status
```

## 2. Развернуть проект

```bash
# Закидываем папку solomoon-club/ на сервер (rsync/scp)
cd ~/solomoon-club

# Настроить пароли
cp .env.example .env
nano .env   # поменять все CHANGE_ME

# Подставить пароли в icecast.xml
chmod +x scripts/*.sh
./scripts/configure.sh

# Создать папку для музыки
mkdir -p music
```

## 3. Залить музыку (≥ 120 минут!)

```bash
# С локальной машины:
rsync -avh --progress /path/to/your/music/ user@95.165.172.153:~/solomoon-club/music/

# Поддерживаются: .mp3 .flac .ogg .opus .m4a .wav
```

**Опционально (рекомендую):** нормализовать громкость один раз:

```bash
# На сервере, после заливки:
./scripts/normalize-music.sh ./music
```

Это запишет EBU R128 теги в файлы и треки будут одинаковой громкости в эфире
без runtime-нормализации в liquidsoap.

## 4. Запуск

```bash
docker compose up -d
docker compose logs -f
```

Должно появиться `=== SoloMoon's Club is on air ===` в логах liquidsoap.

## 5. Проверка

```bash
# Веб-интерфейс Icecast (статистика, кто слушает)
http://95.165.172.153:8000/

# Сам стрим — открой в VLC, Foobar, mpv:
mpv http://95.165.172.153:8000/stream.mp3

# JSON-метаданные (что сейчас играет):
curl http://95.165.172.153:8000/status-json.xsl
```

## 6. Обновление плейлиста

Liquidsoap перечитывает `/music` каждые 30 минут (после смены трека).
Дозалил треки → подождал → они в ротации.

Чтобы перезагрузить **немедленно**:

```bash
# Подключиться к telnet liquidsoap (изнутри контейнера)
docker exec -it solomoon-liquidsoap liquidsoap-cli telnet
> fallback.reload
> exit
```

или просто:

```bash
docker compose restart liquidsoap
```

(перезапуск ~2 сек, слушатели почти не заметят).

## 7. Заявка в OctothorpTeam

Когда станция работает — подавай заявку с этими полями:

- **Название:** SoloMoon's Club
- **Жанры:** House, Deep House, EDM, R&B
- **Описание:** _(будет в фазе 2)_
- **Ссылка на поток:** `http://95.165.172.153:8000/stream.mp3`
- **Ссылка на плейлист:** _(будет в фазе 2 после сайта; пока можно дать список треков текстом или Spotify-плейлист)_

---

## Troubleshooting

**Liquidsoap пишет "no source available":**
- Проверь, что в `./music/` лежат поддерживаемые файлы (`ls music/`).
- Проверь права: `chmod -R a+r music/`.

**Icecast не отдаёт стрим:**
- `docker compose logs icecast` — ищи `Connection refused` или ошибки auth.
- Проверь, что пароли в `icecast.xml` совпадают с `.env`.

**Латенси > 5 сек:**
- Проверь, что в icecast.xml стоит `<burst-size>0</burst-size>`.
- Проверь, что в radio.liq стоит `buffer(buffer=0.2, ...)`.
- Клиентский плеер (особенно `<audio>` в браузере) сам держит ~1.5 сек буфера — ниже не прыгнем.

**Хочу видеть, кто слушает:**
- `http://95.165.172.153:8000/admin/` (логин: admin / пароль из .env)

---

## Что будет дальше

- **Фаза 2:** бренд-пак (лого, палитра) + публичный сайт `solomoon-club.tld` + плеер + nowplaying.
- **Фаза 3:** добавить `input.harbor` в liquidsoap → подключить radio-api → live режим.
- **Фаза 4:** DJ-пульт (React) с 2 деками, EQ, BPM, hot-cues, sampler.
