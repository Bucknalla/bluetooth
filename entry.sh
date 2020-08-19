#!/bin/bash
set -e

# Run balena base image entrypoint script
/usr/bin/entry.sh echo "Running balena base image entrypoint..."

# Bluetooth primitive environment variables and defaults
DEVICE_NAME=${BLUETOOTH_DEVICE_NAME:-$(printf "balenaSound %s"$(hostname | cut -c -4))}
HCI_INTERFACE=${BLUETOOTH_HCI_INTERFACE:-"hci0"}
PAIRING_MODE=${BLUETOOTH_PAIRING_MODE:-"SSP"}
PIN_CODE=${BLUETOOTH_PIN_CODE:-"0000"}

echo "--- Bluetooth ---"
echo "Starting bluetooth service with settings:"
echo "- Device name: "$DEVICE_NAME
echo "- HCI interface: "$HCI_INTERFACE
echo "- Pairing mode: "$PAIRING_MODE
echo "- PIN code: "$PIN_CODE

# Bail out if provided HCI interface is invalid
BT_INFO=$(btmgmt info)
echo "$BT_INFO"
if [[ "$BT_INFO" != *"$HCI_INTERFACE"* ]]; then
  echo "Exiting... selected HCI interface is invalid: $HCI_INTERFACE"
  exit 0
fi

# Set device name
btmgmt --index $HCI_INTERFACE name "$DEVICE_NAME"

# Ensure bluetooth is ready to connect
btmgmt --index $HCI_INTERFACE connectable on
btmgmt --index $HCI_INTERFACE pairable on
btmgmt --index $HCI_INTERFACE discov on

# Set bluetooth pairing mode:
# - SSP (default): Secure Simple Pairing, no PIN code required
# - LEGACY: disable SSP mode, PIN code required
if [[ $PAIRING_MODE == "LEGACY" ]]; then
  AGENT_CAPABILITY="KeyboardDisplay"
  btmgmt --index $HCI_INTERFACE ssp off
  echo "Pairing mode set to 'Legacy Pairing Mode (LPM)'. PIN code is required."
else 
  AGENT_CAPABILITY="NoInputNoOutput"
  btmgmt --index $HCI_INTERFACE ssp on
  echo "Pairing mode set to 'Secure Simple Pairing Mode (SSPM)'. PIN code is NOT required."
fi

# If command starts with an option, prepend bluetooth-agent to it
if [[ "${1#-}" != "$1" ]]; then
  set -- bluetooth-agent "$@"
fi

# Set bluetooth-agent flags if we are running it
if [[ "$1" == *"bluetooth-agent"* ]]; then
  shift
  set -- python bluetooth-agent --interface $HCI_INTERFACE --capability $AGENT_CAPABILITY --pincode $PIN_CODE "$@"
fi

exec "$@"
