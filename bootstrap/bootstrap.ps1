# Installs Talos on the VMs, bootstraps Kubernetes and installs Cilium.
# Run ONCE per cluster:  .\bootstrap.ps1
# Needs talosctl, kubectl and helm on PATH.
# Expects this layout:
#   <somewhere>\homelab\bootstrap\bootstrap.ps1   (this file)
#   <somewhere>\homelab\talos\...
#   <somewhere>\homelab-gitops\manifests\cilium\values.yaml

$ClusterName   = "homelab"
$TalosVersion  = "v1.13.3"
$CiliumVersion = "1.20.3"             # keep in sync with apps/cilium.yaml in homelab-gitops
$ControlIp     = "192.168.50.49"      # <- control plane VM IP
$WorkerIps     = @("192.168.50.51")   # <- worker VM IP(s)

# All paths are relative to this script, so it works from any folder.
$TalosDir     = "$PSScriptRoot/../talos"
$CiliumValues = "$PSScriptRoot/../../homelab-gitops/manifests/cilium/values.yaml"
$Secrets      = "$PSScriptRoot/secrets.yaml"
$Out          = "$PSScriptRoot/rendered"
$TalosConfig  = "$Out/talosconfig"
$KubeConfig   = "$Out/kubeconfig"
$CiliumValues = "$PSScriptRoot/../homelab-gitops/manifests/cilium/values.yaml"
function Invoke-Talos {
  & talosctl @args
  if ($LASTEXITCODE -ne 0) { throw "talosctl $($args -join ' ') failed" }
}
function Invoke-Helm {
  & helm @args
  if ($LASTEXITCODE -ne 0) { throw "helm $($args -join ' ') failed" }
}
function Wait-Until([scriptblock]$Try, [string]$What, [int]$Tries = 40) {
  for ($i = 1; $i -le $Tries; $i++) {
    & $Try 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Host "   waiting for $What ($i/$Tries)..."
    Start-Sleep -Seconds 15
  }
  throw "Timed out waiting for $What"
}

if (-not (Test-Path $CiliumValues)) { throw "Cilium values not found at $CiliumValues" }
New-Item -ItemType Directory -Force $Out | Out-Null

Write-Host "== Getting the Image Factory schematic ID"
$schematic = Invoke-RestMethod -Method Post -Uri "https://factory.talos.dev/schematics" `
               -InFile "$TalosDir/customization.yaml" -ContentType "application/yaml"
if (-not $schematic.id) { throw "Image Factory returned no schematic ID" }
$InstallImage = "factory.talos.dev/metal-installer/$($schematic.id):$TalosVersion"
Write-Host "   Installer: $InstallImage"

Write-Host "== Generating cluster secrets (only if missing)"
if (-not (Test-Path $Secrets)) { Invoke-Talos gen secrets -o $Secrets }

Write-Host "== Generating machine configs"
Invoke-Talos gen config $ClusterName "https://${ControlIp}:6443" `
  --with-secrets $Secrets `
  --install-image $InstallImage `
  --config-patch "@$TalosDir/patches/common.yaml" `
  --config-patch "@$TalosDir/patches/proxmox-machine.yaml" `
  --config-patch "@$TalosDir/patches/cilium.yaml" `
  --config-patch-control-plane "@$TalosDir/patches/control.yaml" `
  --config-patch "@$TalosDir/patches/cilium.yaml" `
  --output $Out --force

Invoke-Talos --talosconfig $TalosConfig config endpoint $ControlIp
Invoke-Talos --talosconfig $TalosConfig config node $ControlIp

Write-Host "== Applying configs (Talos installs to disk and reboots)"
Invoke-Talos apply-config --insecure -n $ControlIp -f "$Out/controlplane.yaml"
foreach ($ip in $WorkerIps) {
  Invoke-Talos apply-config --insecure -n $ip -f "$Out/worker.yaml"
}

Write-Host "== Bootstrapping etcd on the control plane"
Wait-Until { talosctl --talosconfig $TalosConfig bootstrap -n $ControlIp -e $ControlIp } "the control plane to accept bootstrap"

Write-Host "== Fetching kubeconfig"
Wait-Until { talosctl --talosconfig $TalosConfig kubeconfig $KubeConfig -n $ControlIp -e $ControlIp --force } "the kubeconfig"
Wait-Until { kubectl --kubeconfig $KubeConfig get --raw /readyz } "the Kubernetes API"

Write-Host "== Installing Cilium $CiliumVersion (nodes stay NotReady until this is done)"
Invoke-Helm upgrade --install cilium cilium `
  --repo https://helm.cilium.io --version $CiliumVersion `
  --namespace kube-system `
  --values $CiliumValues `
  --kubeconfig $KubeConfig

Write-Host "== Waiting for the cluster to become healthy"
Invoke-Talos --talosconfig $TalosConfig health -n $ControlIp --wait-timeout 15m

Write-Host ""
Write-Host "Done. Try:"
Write-Host "  `$env:KUBECONFIG = `"$((Resolve-Path $KubeConfig).Path)`""
Write-Host "  kubectl get nodes"
