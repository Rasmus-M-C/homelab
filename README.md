# Talos on Proxmox (Terraform + talosctl)

Adapted from the itguyjournals guide for 1 control plane (pve1) + 1 worker (pve2).

```
terraform/   VMs on Proxmox (Telmate provider)
talos/       Image Factory customization + Talos config patches
scripts/     ISO download, run on each Proxmox host
bootstrap/   bootstrap.ps1 – install Talos + Kubernetes from Windows
ansible/     install.yaml – the same, as in the guide (Linux only)
```

## 0. Prerequisites
- VT-x / SVM enabled in the BIOS of both Proxmox hosts.
- `terraform`, `talosctl` and `kubectl` on your PC.
- Delete the VMs from earlier attempts (or `terraform destroy` in those folders).

## 1. Talos ISO (on each Proxmox host)
Copy `scripts/download-talos-iso.sh` to the host (or paste it into the Shell) and run
`bash download-talos-iso.sh`. Do this on both pve1 and pve2.

## 2. DHCP reservations
In your router, reserve an IP for each MAC in `terraform/values.tfvars`
(BC:24:13:5F:39:D1 -> control plane, BC:24:13:5F:39:E1 -> worker).
Put the same IPs in `bootstrap/bootstrap.ps1` (or `ansible/install.yaml`).

## 3. Create the VMs
```powershell
cd terraform
Copy-Item secrets.auto.tfvars.example secrets.auto.tfvars   # fill in
terraform init
terraform plan -var-file=values.tfvars -out=create-plan
terraform apply create-plan
```
Each VM's Proxmox console should show the Talos dashboard in maintenance mode
with the reserved IP.

## 4. Install Talos and bootstrap Kubernetes (once)
```powershell
cd ..\bootstrap
.\bootstrap.ps1
$env:KUBECONFIG = "$PWD\rendered\kubeconfig"
kubectl get nodes
```
Back up `bootstrap/secrets.yaml` and `bootstrap/rendered/talosconfig`;
you need them to manage the cluster later.
