#!/bin/bash
# Fleet Dispatch - Automated Deployment Script
# Usage: ./deploy.sh

set -e

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="fleet-dispatch"
PORT=8000

echo "=========================================="
echo "  Fleet Dispatch - Deployment Script"
echo "=========================================="
echo "App directory: $APP_DIR"
echo ""

# 1. Python virtual environment
echo "[1/5] Setting up Python virtual environment..."
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv"
    echo "  Created new venv"
else
    echo "  venv already exists"
fi
source "$APP_DIR/venv/bin/activate"

# 2. Install Python dependencies
echo "[2/5] Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r "$APP_DIR/backend/requirements.txt" -q
echo "  Dependencies installed"

# 3. Verify Ollama
echo "[3/5] Checking Ollama..."
if command -v ollama &> /dev/null; then
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "  Ollama is running"
        if ollama list 2>/dev/null | grep -q "gpt-oss"; then
            echo "  gpt-oss model found"
        else
            echo "  WARNING: gpt-oss model not found. Run: ollama pull gpt-oss"
        fi
    else
        echo "  WARNING: Ollama not running. Run: ollama serve"
    fi
else
    echo "  WARNING: Ollama not installed. See https://ollama.ai"
fi

# 4. Setup systemd service
echo "[4/5] Setting up systemd service..."
if [ -f "$APP_DIR/fleet-dispatch.service" ]; then
    # Update paths in service file
    sed "s|WorkingDirectory=.*|WorkingDirectory=$APP_DIR|g; s|ExecStart=.*|ExecStart=$APP_DIR/venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port $PORT|g" \
        "$APP_DIR/fleet-dispatch.service" | sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    echo "  Service installed and enabled"
else
    echo "  WARNING: fleet-dispatch.service not found, skipping"
fi

# 5. Start the service
echo "[5/5] Starting Fleet Dispatch..."
sudo systemctl restart $SERVICE_NAME
sleep 2

if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo ""
    echo "=========================================="
    echo "  Deployment successful!"
    echo "=========================================="
    echo ""
    echo "  Web App:      http://$(hostname -I | awk '{print $1}'):$PORT"
    echo "  APK Download: http://$(hostname -I | awk '{print $1}'):$PORT/download"
    echo "  API Docs:     http://$(hostname -I | awk '{print $1}'):$PORT/docs"
    echo ""
    echo "  Manage service:"
    echo "    sudo systemctl status $SERVICE_NAME"
    echo "    sudo systemctl restart $SERVICE_NAME"
    echo "    sudo journalctl -u $SERVICE_NAME -f"
    echo ""
else
    echo ""
    echo "WARNING: Service may not have started correctly."
    echo "Check logs: sudo journalctl -u $SERVICE_NAME -n 20"
    echo ""
    echo "To run manually:"
    echo "  cd $APP_DIR"
    echo "  source venv/bin/activate"
    echo "  uvicorn backend.main:app --host 0.0.0.0 --port $PORT"
fi
