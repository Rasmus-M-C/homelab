# Installs Talos on the VMs and bootstraps Kubernetes. Run ONCE per cluster,
# from this folder:  cd bootstrap ; .\bootstrap.ps1
# Needs talosctl on PATH (e.g. winget install Sidero.talosctl, or download
# talosctl-windows-amd64.exe from the Talos GitHub releases).

$ClusterName  = "homelab"
$TalosVersion = "v1.13.3"          # keep in sync with download-talos-iso.sh
$ControlIp    = "192.168.50.49"     # <- DHCP reservation for the control plane MAC
$WorkerIps    = @("192.168.50.51")  # <- DHCP reservation(s) for the worker MAC(s)
$Out          = "rendered"
$TalosConfig  = "$Out/talosconfig"

function Invoke-Talos {
  & talosctl @args
  if ($LASTEXITCODE -ne 0) { throw "talosctl $($args -join ' ') failed" }
}

New-Item -ItemType Directory -Force $Out | Out-Null

Write-Host "== Getting the Image Factory schematic ID"
$schematic    = Invoke-RestMethod -Method Post -Uri "https://factory.talos.dev/schematics" `
                  -InFile "../talos/customization.yaml" -ContentType "application/yaml"
$InstallImage = "factory.talos.dev/metal-installer/$($schematic.id):$TalosVersion"
Write-Host "   Installer: $InstallImage"

Write-Host "== Generating cluster secrets (only if missing)"
if (-not (Test-Path "secrets.yaml")) { Invoke-Talos gen secrets -o secrets.yaml }

Write-Host "== Generating machine configs"
Invoke-Talos gen config $ClusterName "https://${ControlIp}:6443" `
  --with-secrets secrets.yaml `
  --install-image $InstallImage `
  --config-patch "@../talos/patches/common.yaml" `
  --config-patch "@../talos/patches/proxmox-machine.yaml" `
  --config-patch-control-plane "@../talos/patches/control.yaml" `
  --output $Out --force

Invoke-Talos --talosconfig $TalosConfig config endpoint $ControlIp
Invoke-Talos --talosconfig $TalosConfig config node $ControlIp

Write-Host "== Applying configs (Talos installs to disk and reboots)"
Invoke-Talos apply-config --insecure -n $ControlIp -f "$Out/controlplane.yaml"
foreach ($ip in $WorkerIps) {
  Invoke-Talos apply-config --insecure -n $ip -f "$Out/worker.yaml"
}

Write-Host "== Bootstrapping etcd on the control plane (retries while it reboots)"
$ok = $false
for ($i = 1; $i -le 40 -and -not $ok; $i++) {
  Start-Sleep -Seconds 15
  & talosctl --talosconfig $TalosConfig bootstrap -n $ControlIp -e $ControlIp 2>$null
  $ok = ($LASTEXITCODE -eq 0)
  if (-not $ok) { Write-Host "   not ready yet ($i/40)..." }
}
if (-not $ok) { throw "Bootstrap did not succeed in 10 minutes" }

Write-Host "== Waiting for the cluster to become healthy"
Invoke-Talos --talosconfig $TalosConfig health -n $ControlIp --wait-timeout 15m

Write-Host "== Fetching kubeconfig"
Invoke-Talos --talosconfig $TalosConfig kubeconfig "$Out/kubeconfig" -n $ControlIp -e $ControlIp --force

Write-Host ""
Write-Host "Done. Try:"
Write-Host "  `$env:KUBECONFIG = `"$((Resolve-Path "$Out/kubeconfig").Path)`""
Write-Host "  kubectl get nodes"
