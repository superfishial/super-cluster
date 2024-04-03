Based on this excellent guide: https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/

First, run the workflow for building the Talos image and note the link to the artifact: https://github.com/superfishial/abyss/actions/workflows/build-talos-image.yaml

The convention is to set the hostname of the worker nodes to `nereid-$index` where the index starts from 1

```bash
# Use a version older than latest if you want to test an upgrade
export TALOS_VERSION=v1.6.1
# Keep in mind that device paths might change between reboots so either
# double-check the device path, or use one of the udev paths instead.
export TARGET_DISK="/dev/nvme0n1"

# OPTIONAL in case you need to stop RAID
mdadm --stop /dev/md/*
# wipe drives
wipefs -a /dev/nvme*n1
wipefs -a /dev/sd*
# Download the artifacts from our action run
# Update <GITHUB_TOKEN> with the output of `gh auth token`
# Update <ARTIFACT_ID> with the last section of the url of the artifact of the action run
wget --header "Authorization: Bearer <GITHUB_TOKEN>" -O images.zip https://api.github.com/repos/superfishial/abyss/actions/artifacts/<ARTIFACT_ID>/zip
unzip images.zip
unxz metal-amd64.raw.xz
# Write the raw disk image directly to the hard drive.
dd if=metal-amd64.raw of=$TARGET_DISK && sync

mount LABEL=BOOT /mnt
sed -i 's/console=ttyS0//g' /mnt/grub/grub.cfg
# Remove the console=ttyS0 from the kernel parameters for both entries
# Based on https://github.com/siderolabs/talos/discussions/7465

shutdown -r now
```

Get configuration from `neptune` terraform project via: `terraform output -raw talos_worker_machine_configuration > ../worker-configuration.yaml`
For each of the nodes:

- change the `machine.network.hostname` to include the index of the node such as `nereid-1` and `nereid-2`
- run `talosctl apply-config --insecure -n 88.198.53.24 --file worker-configuration.yaml`
