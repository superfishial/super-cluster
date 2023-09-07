# super-cluster

## Build Talos Image

Based on the guide from Talos: https://github.com/siderolabs/talos

```bash
export HCLOUD_TOKEN=TOKEN_WITH_READ_WRITE_PERMISSIONS
cd talos-snapshot
packer init .
packer build .
```

You may need to update the version of Talos in the Terraform

## Create cluster

Create the file `control-plane/secrets.auto.tfvars` and put in `hetzner_token=TOKEN_WITH_READ_WRITE_PERMISSIONS`

```bash
cd control-plane
terraform init
terraform apply
```

After creation, you can get the configuration for Talos via `terraform output -raw talosconfig > talosconfig` and the Kubernetes config via `terraform output -raw kubeconfig > kubeconfig`. Place the kubeconfig in `~/.config/kube/config` (by default on Linux) or point the `KUBECONFIG` env to the file.
