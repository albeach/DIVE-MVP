#!/bin/bash
# ensure-tools.sh - Ensures all required debugging tools are installed

# Check if tools are already available
echo "Verifying required networking tools..."

TOOLS=(
  "curl"
  "dig"
  "nc"
  "jq"
  "traceroute"
  "nmap"
  "ping"
  "tcpdump"
)

MISSING=false

for TOOL in "${TOOLS[@]}"; do
  if ! command -v $TOOL &> /dev/null; then
    echo "❌ $TOOL missing"
    MISSING=true
  else
    echo "✅ $TOOL available"
  fi
done

if $MISSING; then
  echo "Installing missing tools..."
  # These should all be available in the netshoot image, but just in case:
  apk add --no-cache curl bind-tools netcat-openbsd jq busybox-extras nmap tcpdump
fi

echo "Tools verification complete" 