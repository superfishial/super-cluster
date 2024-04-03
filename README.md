# super-cluster

## Build base image

We need to extend the Talos base image with open-iscsi which we do via a GitHub action triggered manually. This will no longer be necessary with Longhorn 1.6 https://github.com/longhorn/longhorn/issues/3161

## Generate Hetzner Cloud snapshot for Talos image

Based on the guide from Talos: https://github.com/siderolabs/talos

```bash
export HCLOUD_TOKEN=TOKEN_WITH_READ_WRITE_PERMISSIONS
cd talos
packer init .
packer build .
```

You may need to update the version of Talos in the Terraform

## Create cluster

Create the file `control-plane/secrets.auto.tfvars` and put in `hetzner_token=TOKEN_WITH_READ_WRITE_PERMISSIONS`

```bash
cd neptune
terraform init
terraform apply
```

After creation, you can get the configuration for Talos via `terraform output -raw talosconfig > talosconfig` and the Kubernetes config via `terraform output -raw kubeconfig > kubeconfig`. Place the kubeconfig in `~/.kube/config` (by default on Linux) or point the `KUBECONFIG` env to the file.
