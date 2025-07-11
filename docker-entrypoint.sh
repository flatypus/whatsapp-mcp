#!/bin/bash

set -e

echo "Starting WhatsApp MCP Docker container..."

mkdir -p /app/whatsapp-bridge/store
mkdir -p /app/data

# Set up data directory symlink for persistence
if [ ! -L /app/whatsapp-bridge/store/messages.db ] && [ -f /app/data/messages.db ]; then
    ln -sf /app/data/messages.db /app/whatsapp-bridge/store/messages.db
fi

if [ ! -L /app/whatsapp-bridge/store/whatsapp.db ] && [ -f /app/data/whatsapp.db ]; then
    ln -sf /app/data/whatsapp.db /app/whatsapp-bridge/store/whatsapp.db
fi

start_whatsapp_bridge() {
    echo "Starting WhatsApp bridge..."
    cd /app/whatsapp-bridge
    
    # Check if we need to authenticate
    if [ ! -f "/app/data/whatsapp.db" ]; then
        echo "=============================================="
        echo "FIRST TIME SETUP - QR CODE AUTHENTICATION"
        echo "=============================================="
        echo ""
        echo "You need to scan a QR code to authenticate WhatsApp."
        echo "The QR code will be displayed in the logs below."
        echo ""
        echo "To authenticate:"
        echo "1. Open WhatsApp on your phone"
        echo "2. Go to Settings > Linked Devices"
        echo "3. Tap 'Link a Device'"
        echo "4. Scan the QR code shown in the logs"
        echo ""
        echo "=============================================="
    fi
    
    # Start the bridge (will show QR code if needed)
    ./whatsapp-bridge &
    BRIDGE_PID=$!
    
    # Wait for bridge to initialize
    sleep 10
    
    return $BRIDGE_PID
}

start_mcp_server() {
    echo "Starting MCP server..."
    cd /app/whatsapp-mcp-server
    
    # Install Python dependencies
    uv sync
    
    # Start the MCP server
    export PORT=${PORT:-8080}
    uv run python -m http.server $PORT &
    MCP_PID=$!
    
    return $MCP_PID
}

cleanup() {
    echo "Shutting down services..."
    if [ ! -z "$BRIDGE_PID" ]; then
        kill $BRIDGE_PID 2>/dev/null || true
    fi
    if [ ! -z "$MCP_PID" ]; then
        kill $MCP_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start services
start_whatsapp_bridge
BRIDGE_PID=$!

# Wait for the bridge to initialize
sleep 15

start_mcp_server
MCP_PID=$!

# Keep the container running
echo "Services started. WhatsApp Bridge PID: $BRIDGE_PID, MCP Server PID: $MCP_PID"
echo "Container is ready. Check logs for QR code if this is first setup."

# Wait for either process to exit
wait