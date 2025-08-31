
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-/srv/flaskapp}"

echo "[deploy] Using APP_DIR=$APP_DIR"

sudo mkdir -p "$APP_DIR"
sudo rsync -a /home/$USER/__upload/ "$APP_DIR"/

# Python venv
if [ ! -d "$APP_DIR/venv" ]; then
  echo "[deploy] Creating venv..."
  sudo python3 -m venv "$APP_DIR/venv"
fi

echo "[deploy] Installing requirements..."
sudo "$APP_DIR/venv/bin/pip" install --upgrade pip
sudo "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# Systemd service
echo "[deploy] Installing systemd service..."
sudo cp "$APP_DIR/deploy/gunicorn.service" /etc/systemd/system/flaskapp.service
sudo systemctl daemon-reload
sudo systemctl enable flaskapp

# Nginx config
echo "[deploy] Configuring Nginx..."
sudo cp "$APP_DIR/nginx/flaskapp.conf" /etc/nginx/sites-available/flaskapp
if [ ! -L /etc/nginx/sites-enabled/flaskapp ]; then
  sudo ln -s /etc/nginx/sites-available/flaskapp /etc/nginx/sites-enabled/flaskapp
fi
if [ -f /etc/nginx/sites-enabled/default ]; then
  sudo rm -f /etc/nginx/sites-enabled/default
fi
sudo nginx -t

# Start / restart services
echo "[deploy] Restarting services..."
sudo systemctl restart flaskapp
sudo systemctl restart nginx

echo "[deploy] Done."
