# SoloMoon's Club — Deployment Guide для Ubuntu 24.04.4 LTS

## Системные требования

- **ОС:** Ubuntu 24.04.4 LTS (Jammy)
- **Архитектура:** x86_64
- **RAM:** ≥ 2GB (рекомендуется 4GB для comfort)
- **Диск:** ≥ 20GB (+ место под музыку)

## 1. Подготовка сервера

### Обновление пакетов
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### Установка Docker Engine (официальный репо)
```bash
# Удалим старые версии, если есть
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Установим зависимости
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Добавим Docker GPG ключ
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавим репозиторий
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установим Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Проверим версию
docker --version
```

### Настройка Docker для текущего пользователя
```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps  # проверяем, что работает без sudo
```

### Открыть порты в файрволе (UFW)
```bash
# Icecast (стрим)
sudo ufw allow 8000/tcp comment "Icecast stream"

# Radio API (DJ-дека)
sudo ufw allow 8080/tcp comment "Radio API for DJ deck"

# SSH (если нужна удалённая помощь)
sudo ufw allow 22/tcp comment "SSH"

# Включить файрвол
sudo ufw enable

# Проверить статус
sudo ufw status
```

## 2. Развёртывание проекта

### Clone репозитория
```bash
cd ~
git clone https://github.com/anch0vu/solomoon_dj.git
cd solomoon_dj
git checkout main
```

### Создание .env файла
```bash
cp .env.example .env
nano .env
```

Обязательные переменные для изменения:
- `ICECAST_SOURCE_PASSWORD` — пароль источника (для liquidsoap)
- `ICECAST_ADMIN_PASSWORD` — пароль администратора Icecast
- `ICECAST_RELAY_PASSWORD` — пароль реле
- `HARBOR_PASSWORD` — пароль для DJ-потока (ffmpeg)
- `DJ_TOKEN` — токен для браузерной деки (генерируй: `openssl rand -hex 32`)
- `SERVER_HOST` — публичный IP или доменное имя

Пример:
```env
ICECAST_SOURCE_PASSWORD=supersecret_source_2024
ICECAST_ADMIN_PASSWORD=supersecret_admin_2024
ICECAST_RELAY_PASSWORD=supersecret_relay_2024
HARBOR_PASSWORD=supersecret_harbor_2024
DJ_TOKEN=abc123def456...  # из openssl rand -hex 32
SERVER_HOST=95.165.172.153  # или your-domain.com
```

### Конфигурация Icecast
```bash
chmod +x scripts/configure.sh
./scripts/configure.sh
```

Скрипт заменит плейсхолдеры в `icecast/icecast.xml` на значения из `.env`.

### Создание папки для музыки
```bash
mkdir -p music
chmod 755 music
```

## 3. Заливка музыки

### С локальной машины (rsync)
```bash
rsync -avh --progress /path/to/your/music/ user@YOUR_SERVER_IP:~/solomoon_dj/music/
```

### Нормализация громкости (рекомендуется)
```bash
./scripts/normalize-music.sh ./music
```

Это однократное действие, которое добавит EBU R128 метаданные в файлы. После этого liquidsoap не будет нормализовать в реальном времени (экономит CPU).

## 4. Запуск

### Сборка и запуск контейнеров
```bash
docker compose build
docker compose up -d
```

### Проверка логов
```bash
# Все логи
docker compose logs -f

# Только конкретный сервис
docker compose logs -f liquidsoap
docker compose logs -f icecast
docker compose logs -f radio-api
```

Ждите строки `=== SoloMoon's Club is on air ===` в логах liquidsoap.

## 5. Проверка работы

### Веб-интерфейс Icecast (статистика, слушатели)
```
http://YOUR_SERVER_IP:8000/
Логин: admin
Пароль: значение ICECAST_ADMIN_PASSWORD из .env
```

### Прямой стрим (откройте в VLC, mpv, Foobar2000)
```
http://YOUR_SERVER_IP:8000/stream.mp3
```

### JSON метаданные (что сейчас играет)
```bash
curl http://YOUR_SERVER_IP:8000/status-json.xsl | jq '.icestats.source[0]'
```

### DJ-дека (браузерный интерфейс)
```
ws://YOUR_SERVER_IP:8080/dj?token=YOUR_DJ_TOKEN
```

## 6. Управление

### Перезагрузка liquidsoap (быстро, слушатели не упадут)
```bash
docker compose restart liquidsoap
```

### Обновление плейлиста (после дозагрузки новых треков)
Liquidsoap перечитывает `/music` каждые 30 минут автоматически. Или немедленно:
```bash
docker exec -it solomoon-liquidsoap liquidsoap-cli telnet
> fallback.reload
> exit
```

### Остановка всей станции
```bash
docker compose down
```

## 7. Обновление проекта

```bash
cd ~/solomoon_dj
git fetch origin
git checkout main
git pull
docker compose build  # пересобрать radio-api
docker compose up -d
```

## 8. Мониторинг и troubleshooting

### Liquidsoap пишет "no source available"
- Проверьте, что в `./music/` лежат файлы: `ls music/`
- Проверьте права: `chmod -R a+r music/`

### Icecast не отдаёт стрим
```bash
docker compose logs icecast | grep -i error
```
- Проверьте совпадение паролей в `.env` и в Icecast
- Проверьте, что liquidsoap подключился (логи liquidsoap)

### Высокая latency (> 5 сек)
- Проверьте `burst-size` в icecast.xml (должен быть 0)
- Проверьте `buffer` в liquidsoap/radio.liq
- Браузерный плеер может добавлять ~1.5 сек буфера

### DJ-дека не работает
```bash
docker compose logs radio-api
```
- Проверьте токены в `.env`
- Проверьте, что `LIQUIDSOAP_HOST=liquidsoap` (не IP)

## 9. Оптимизация для production

### Systemd сервис (автозапуск при перезагрузке)
```bash
sudo tee /etc/systemd/system/solomoon.service > /dev/null << 'UNIT'
[Unit]
Description=SoloMoon's Club — 24/7 Radio Stream
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/solomoon_dj
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl enable solomoon
sudo systemctl start solomoon
sudo systemctl status solomoon
```

### Rotation логов
```bash
docker compose logs --tail 100 > solomoon.log
```

### Backup конфигурации
```bash
tar czf ~/solomoon_backup_$(date +%Y%m%d).tar.gz \
  ~/solomoon_dj/{.env,icecast/*.xml,liquidsoap/*.liq} \
  2>/dev/null || true
```

---

**Support & Questions:**
- GitHub Issues: https://github.com/anch0vu/solomoon_dj/issues
- Docs: https://github.com/anch0vu/solomoon_dj/blob/main/README.md
