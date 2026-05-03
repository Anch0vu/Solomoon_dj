#!/usr/bin/env bash
# SoloMoon's Club — Deploy on Ubuntu 24.04.4 LTS from scratch
# Usage: sudo bash deploy.sh
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/solomoon-club}"
REPO="https://github.com/Anch0vu/Solomoon_dj.git"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo bash deploy.sh)" >&2
  exit 1
fi

echo "═════════════════════════════════════════════════════════════"
echo "  SoloMoon's Club — Production Deploy"
echo "  Ubuntu 24.04.4 LTS"
echo "═════════════════════════════════════════════════════════════"
echo ""

# ── Step 1: System packages ────────────────────────────────────────
echo ">>> Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl git ca-certificates ufw libxml2-utils >/dev/null

# ── Step 2: Docker ─────────────────────────────────────────────────
if ! command -v docker >/dev/null; then
  echo ">>> Installing Docker..."
  curl -fsSL https://get.docker.com | sh >/dev/null
fi

systemctl enable --now docker >/dev/null 2>&1

# Verify Docker works
if ! docker ps >/dev/null 2>&1; then
  echo "ERROR: Docker not running or permission issue"
  exit 1
fi

echo "✓ Docker installed and running"

# ── Step 3: Firewall ───────────────────────────────────────────────
echo ">>> Configuring firewall..."
ufw --force enable >/dev/null 2>&1 || true
ufw allow 22/tcp   comment "SSH"      >/dev/null 2>&1 || true
ufw allow 8000/tcp comment "Icecast"  >/dev/null 2>&1 || true
ufw allow 8080/tcp comment "Radio API" >/dev/null 2>&1 || true

echo "✓ Firewall configured"

# ── Step 4: Clone / Update repository ──────────────────────────────
echo ">>> Setting up repository..."
if [ -d "$PROJECT_DIR/.git" ]; then
  echo "  (updating existing clone)"
  git -C "$PROJECT_DIR" fetch origin main >/dev/null
  git -C "$PROJECT_DIR" checkout main >/dev/null
  git -C "$PROJECT_DIR" reset --hard origin/main >/dev/null
else
  echo "  (cloning from GitHub)"
  git clone "$REPO" "$PROJECT_DIR" >/dev/null
fi

cd "$PROJECT_DIR"
echo "✓ Repository ready at $PROJECT_DIR"

# ── Step 5: Create directories ─────────────────────────────────────
echo ">>> Creating directory structure..."
mkdir -p icecast liquidsoap music deck
chmod 755 music

# ── Step 6: Generate .env with random passwords ────────────────────
echo ">>> Generating .env..."
if [ ! -f .env ]; then
  # Generate secure random passwords
  gen_password() {
    head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 16
  }

  cat > .env <<'EOF'
# SoloMoon's Club Configuration
# Generated: $(date)

# Icecast streaming server
ICECAST_SOURCE_PASSWORD=$(gen_password)
ICECAST_ADMIN_PASSWORD=$(gen_password)
ICECAST_RELAY_PASSWORD=$(gen_password)

# Live DJ streaming (Phase 3)
HARBOR_PASSWORD=$(gen_password)
DJ_TOKEN=$(gen_password)

# Deployment
SERVER_HOST=localhost
SERVER_PORT=8000
EOF

  # Replace placeholders with actual random values
  sed -i "s|\$(gen_password)|$(gen_password)|g" .env

  chmod 600 .env
  echo "✓ .env generated with secure passwords"
else
  echo "✓ .env already exists (not overwriting)"
fi

# Load .env for later use
set -a
source .env
set +a

# ── Step 7: Configure Icecast ──────────────────────────────────────
echo ">>> Configuring Icecast..."

# Get external IP for stream URL
EXT_IP=$(curl -s4 https://api.ipify.org 2>/dev/null || echo "localhost")

# Copy and configure icecast.xml
if [ -f icecast.xml ]; then
  cp icecast.xml icecast/icecast.xml.template
fi

cat > icecast/icecast.xml <<ICECAST_CONF
<icecast>
    <location>Moscow</location>
    <admin>admin@solomoon.club</admin>
    <hostname>$EXT_IP</hostname>

    <limits>
        <clients>200</clients>
        <sources>4</sources>
        <queue-size>65536</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <burst-on-connect>0</burst-on-connect>
        <burst-size>0</burst-size>
    </limits>

    <authentication>
        <source-password>$ICECAST_SOURCE_PASSWORD</source-password>
        <relay-password>$ICECAST_RELAY_PASSWORD</relay-password>
        <admin-user>admin</admin-user>
        <admin-password>$ICECAST_ADMIN_PASSWORD</admin-password>
    </authentication>

    <listen-socket>
        <port>8000</port>
    </listen-socket>

    <http-headers>
        <header name="Access-Control-Allow-Origin" value="*" />
    </http-headers>

    <mount type="normal">
        <mount-name>/stream.mp3</mount-name>
        <max-listeners>200</max-listeners>
        <stream-name>SoloMoon's Club</stream-name>
        <stream-description>House · Deep House · EDM · R&amp;B</stream-description>
        <stream-url>http://$EXT_IP:8000/</stream-url>
        <genre>House Deep-House EDM R&amp;B</genre>
        <bitrate>320</bitrate>
        <type>audio/mpeg</type>
        <public>0</public>
        <fallback-override>0</fallback-override>
    </mount>

    <fileserve>1</fileserve>
    <paths>
        <basedir>/usr/share/icecast2</basedir>
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <pidfile>/var/run/icecast2/icecast2.pid</pidfile>
        <alias source="/" destination="/status.xsl"/>
    </paths>

    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <loglevel>3</loglevel>
        <logsize>10000</logsize>
    </logging>

    <security>
        <chroot>0</chroot>
    </security>
</icecast>
ICECAST_CONF

echo "✓ Icecast configured for $EXT_IP"

# ── Step 8: Build and start services ───────────────────────────────
echo ""
echo ">>> Building Docker images..."
docker compose build --quiet

echo ""
echo ">>> Starting services..."
docker compose up -d

# Wait for services to be ready
sleep 3

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "  ✓ Deployment Complete!"
echo "═════════════════════════════════════════════════════════════"
echo ""

# ── Service status ─────────────────────────────────────────────────
echo "Service Status:"
docker compose ps

echo ""
echo "Access Points:"
echo "  • Icecast Web:   http://$EXT_IP:8000/"
echo "  • Stream URL:    http://$EXT_IP:8000/stream.mp3"
echo "  • Admin Panel:   http://$EXT_IP:8000/admin/"
echo "    (login: admin / password: check .env ICECAST_ADMIN_PASSWORD)"
echo ""

# ── Next steps ─────────────────────────────────────────────────────
echo "Next Steps:"
echo "  1. Upload music files:"
echo "     rsync -avh --progress /path/to/music/ root@$EXT_IP:$PROJECT_DIR/music/"
echo ""
echo "  2. Check logs:"
echo "     cd $PROJECT_DIR && docker compose logs -f liquidsoap"
echo ""
echo "  3. Test stream:"
echo "     curl http://$EXT_IP:8000/status-json.xsl | jq"
echo ""
echo "  4. View project:"
echo "     cd $PROJECT_DIR"
echo ""

# ── Warnings ───────────────────────────────────────────────────────
echo "Important:"
echo "  • Keep .env file secure (contains passwords)"
echo "  • Music directory is empty — upload files to enable streaming"
echo "  • Update SERVER_HOST in .env if using a domain name"
echo "  • Consider setting up backup and log rotation"
echo ""
