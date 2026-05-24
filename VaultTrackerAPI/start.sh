#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Activating virtual environment..."
source venv/bin/activate

echo "Starting VaultTrackerAPI on http://localhost:8001"
echo "API docs: http://localhost:8001/docs"
echo "Press Ctrl+C to stop."
echo ""

uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
