#!/bin/bash
# Run on EACH Proxmox host (Shell in the web UI, or ssh root@<host>).
# Builds the Talos image with the QEMU guest agent via the Image Factory and
# saves the ISO where Proxmox's "local" storage expects ISOs.
set -euo pipefail

TALOS_VERSION="v1.13.3" # keep in sync with bootstrap.ps1 / install.yaml

ID=$(
  curl -sf -X POST --data-binary @- https://factory.talos.dev/schematics <<'YAML' | sed -E 's/.*"id":"([^"]+)".*/\1/'
customization:
  extraKernelArgs:
    - net.ifnames=0 # interface is called eth0
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
YAML
)

echo "Schematic ID: $ID"
wget -O /var/lib/vz/template/iso/talos-amd64.iso \
  "https://factory.talos.dev/image/${ID}/${TALOS_VERSION}/metal-amd64.iso"
echo "Saved as local:iso/talos-amd64.iso"
