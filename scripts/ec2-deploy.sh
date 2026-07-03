#!/usr/bin/env bash
set -euo pipefail    # safety net for scripts: 
# -e = stop immediately if any command fails. -u = treat using an undefined variable as an error.
# -o pipefail = if any command in a pipeline (a | b) fails, the whole pipeline counts as failed (not just the last command).

APP_DIR="${APP_DIR:-$(pwd)}"
APP_USER="${APP_USER:-ubuntu}"
PUBLIC_HOST="${PUBLIC_HOST:-${EC2_PUBLIC_IP:-}}"
PUBLIC_FRONTEND_ORIGIN="${PUBLIC_FRONTEND_ORIGIN:-}"
FRONTEND_API_BASE_URL="${FRONTEND_API_BASE_URL:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4.1-mini}"
AI_MODE="${AI_MODE:-mock}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
STORAGE_MODE="${STORAGE_MODE:-s3}"
MATERIALS_BUCKET="${MATERIALS_BUCKET:-}"
TABLE_NAME="${TABLE_NAME:-}"

cd "$APP_DIR"

# If PUBLIC_HOST wasn't passed in, ask AWS's special internal metadata address (169.254.169.254 — only reachable from inside an EC2 instance) for the machine's public IP.
# If that still fails (e.g., no public IP, or metadata blocked), fall back to localhost.
if [[ -z "$PUBLIC_HOST" ]]; then
  PUBLIC_HOST="$(curl -fsSL http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
fi
if [[ -z "$PUBLIC_HOST" ]]; then
  PUBLIC_HOST="localhost"
fi

# Same idea — if these weren't explicitly passed in, build them from the public host (e.g., http://1.2.3.4 and http://1.2.3.4/api).
if [[ -z "$PUBLIC_FRONTEND_ORIGIN" ]]; then
  PUBLIC_FRONTEND_ORIGIN="http://${PUBLIC_HOST}"
fi
if [[ -z "$FRONTEND_API_BASE_URL" ]]; then
  FRONTEND_API_BASE_URL="http://${PUBLIC_HOST}/api"
fi

# Writes a JSON file (backend/env.ec2.json) that AWS SAM will use to inject environment variables into the Lambda function CloudMentorFunction when 
# it runs locally. This is how the OpenAI key, table name, S3 bucket, CORS origin, etc., reach the actual backend code.
mkdir -p backend
cat > backend/env.ec2.json <<JSON
{
  "CloudMentorFunction": {
    "OPENAI_API_KEY": "${OPENAI_API_KEY}",
    "OPENAI_MODEL": "${OPENAI_MODEL}",
    "AI_MODE": "${AI_MODE}",
    "TABLE_NAME": "${TABLE_NAME}",
    "MATERIALS_BUCKET": "${MATERIALS_BUCKET}",
    "CORS_ORIGIN": "${PUBLIC_FRONTEND_ORIGIN}",
    "STORAGE_MODE": "${STORAGE_MODE}",
    "LOCAL_DEV": "false",
    "AWS_REGION": "${AWS_REGION}"
  }
}
JSON

echo "==> Installing backend dependencies and building SAM app"
cd "$APP_DIR/backend"
npm ci || npm install    # npm ci does a clean, reproducible install from package-lock.json; if that fails (e.g. no lockfile), falls back to a regular npm install.
sam build                # AWS SAM (Serverless Application Model) compiles/packages the Lambda function(s) so they're ready to run.

echo "==> Creating systemd service for SAM local API"
sudo tee /etc/systemd/system/cloudmentor-api.service >/dev/null <<SERVICE
[Unit]
Description=CloudMentor SAM Local API
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
User=${APP_USER}
Group=docker
WorkingDirectory=${APP_DIR}/backend
Environment=AWS_REGION=${AWS_REGION}
Environment=AWS_DEFAULT_REGION=${AWS_REGION}
ExecStart=/usr/local/bin/sam local start-api --host 127.0.0.1 --port 3000 --env-vars ${APP_DIR}/backend/env.ec2.json
Restart=always
RestartSec=8

[Install]
WantedBy=multi-user.target
SERVICE
sudo systemctl daemon-reload
sudo systemctl enable --now cloudmentor-api
sudo systemctl restart cloudmentor-api

echo "==> Building frontend for EC2 IP"
cd "$APP_DIR/frontend"
cat > .env.production <<ENV
VITE_API_BASE_URL=${FRONTEND_API_BASE_URL}
ENV
npm ci || npm install
npm run build

echo "==> Publishing frontend to /var/www/cloudmentor"
sudo mkdir -p /var/www/cloudmentor
sudo rsync -a --delete dist/ /var/www/cloudmentor/
sudo chown -R www-data:www-data /var/www/cloudmentor

echo "==> Configuring Nginx"
sudo tee /etc/nginx/sites-available/cloudmentor >/dev/null <<NGINX
server {
    listen 80 default_server;
    server_name _;

    root /var/www/cloudmentor;
    index index.html;

    location /api/ {
        rewrite ^/api/(.*)$ /\$1 break;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sfn /etc/nginx/sites-available/cloudmentor /etc/nginx/sites-enabled/cloudmentor
sudo nginx -t
sudo systemctl reload nginx

cat <<OUT

Deployment complete.
Frontend: ${PUBLIC_FRONTEND_ORIGIN}
Backend through Nginx: ${FRONTEND_API_BASE_URL}
Backend local health from EC2: curl http://127.0.0.1:3000/health
Public health through Nginx: curl ${FRONTEND_API_BASE_URL}/health
Logs: sudo journalctl -u cloudmentor-api -f
OUT
