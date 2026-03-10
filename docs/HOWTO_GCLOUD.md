# Run on Google Cloud

Assumes gcloud CLI is installed and authenticated (`gcloud auth login`).

> **For experienced users.** Cloud infrastructure can incur unexpected costs if resources are not
> cleaned up promptly. Spot VMs may be preempted mid-simulation with no refund for partial work.
> Persistent disks and buckets continue billing even when the instance is stopped or deleted.
> Monitor your GCP billing dashboard and set a budget alert before proceeding.
>
> **Cost:** `n2-highcpu-64` spot in `us-central1` runs ~$0.67/hr. Persistent disk (2 TB)
> costs ~$0.08/GB/month (~$163/month) regardless of whether the instance is running.
> Delete both the instance **and** the disk when done.

## Create Project

```bash
## check your configurations
gcloud config configurations list
gcloud config configurations activate <--your-configuration-->

gcloud projects create flowunsteady --name="FLOWUnsteady Simulation"
gcloud config set project flowunsteady

# Link billing account (required before enabling APIs)
BILLING_ACCOUNT=$(gcloud billing accounts list --format='value(name)' --limit=1)
gcloud billing projects link flowunsteady --billing-account=$BILLING_ACCOUNT
```

## One-Time Project Setup

```bash
gcloud services enable compute.googleapis.com iap.googleapis.com

# Allow IAP TCP tunneling for SSH (one-time per project, no public IP needed)
gcloud compute firewall-rules create allow-iap-ssh \
    --allow tcp:22 \
    --source-ranges 35.235.240.0/20 \
    --description "IAP SSH tunneling"
```

## Request CPU Quota Increase

New GCP projects default to 32 CPUs globally. Request an increase before launching:

1. Go to **IAM & Admin → Quotas** in the GCP Console
2. Filter by **"CPUS_ALL_REGIONS"**
3. Request an increase to **64** (or 96 to have headroom)

Approval is typically automatic within minutes for small increases on billing-verified accounts.

Alternatively, check current quota:

```bash
gcloud compute project-info describe --project flowunsteady \
    --format='value(quotas[name=CPUS_ALL_REGIONS].limit)'
```

## Launch Instance

```bash
# Spot VM (~70% cheaper than on-demand; may be preempted)
gcloud compute instances create flowunsteady \
    --zone us-central1-a \
    --machine-type n2-highcpu-64 \
    --image-family debian-12 \
    --image-project debian-cloud \
    --boot-disk-size 10GB \
    --boot-disk-type pd-ssd \
    --provisioning-model SPOT \
    --instance-termination-action STOP
```

> `n2-highcpu-32` = 64 vCPU, 64 GB RAM. If the simulation runs out of memory, use
> `n2-highcpu-64` = 32 vCPU, 64 GB RAM. If the simulation runs out of memory, use
> `n2-standard-32` (32 vCPU, 128 GB) instead.

## Attach Persistent Disk

```bash
gcloud compute disks create flowunsteady-data \
    --zone us-central1-a \
    --size 2TB \
    --type pd-standard

gcloud compute instances attach-disk flowunsteady \
    --disk flowunsteady-data \
    --zone us-central1-a

gcloud compute ssh flowunsteady --tunnel-through-iap --zone us-central1-a

```

On the instance, format and mount (first time only):

```bash
sudo mkfs -t ext4 /dev/sdb # first time only

sudo mkdir -p /mnt/persistent-disk
sudo mount /dev/sdb /mnt/persistent-disk

# Auto-mount on reboot
echo "$(sudo blkid -s UUID -o value /dev/sdb)  /mnt/persistent-disk  ext4  defaults  0  2" \
    | sudo tee -a /etc/fstab
```

## Create Backup Bucket

```bash
# Bucket names must be globally unique; project ID prefix avoids conflicts
gsutil mb -l us-central1 gs://flowunsteady-$(gcloud config get-value project)
```

## Connect via IAP

No public IP or per-IP firewall rules needed — authenticates via your Google identity.

```bash
gcloud compute ssh flowunsteady --tunnel-through-iap --zone us-central1-a
```

## Install Tools

```bash
sudo apt-get update && sudo apt-get install -y docker.io git make screen
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

## Set Up Output Directory

```bash
sudo mkdir -p /mnt/persistent-disk/flowunsteady_output
sudo chown 1000:1003 /mnt/persistent-disk/flowunsteady_output   # match runner uid in container
```

## Clone and Configure

```bash
cd ~
git clone https://github.com/lancerushing/flowunsteady-starter
cd flowunsteady-starter
```

Edit `Makefile` to point `OUTPUT_PATH` at the disk:

```makefile
OUTPUT_PATH = /mnt/persistent-disk/flowunsteadRy_output
```

## Build and Prepare

```bash
make docker-build      # ~5 min (compiles Python 3.9 from source)
mkdir -p ./.julia
make prepare-julia     # ~2 min (downloads/compiles Julia packages)
```

### Optional save the docker image:

```bash
docker save flowunsteady-runner:dev-py39 | gzip > /mnt/persistent-disk/flowunsteady-runner-dev-py39.tar.gz
```

Restore next time

```bash
gunzip -c /mnt/persistent-disk/flowunsteady-runner-dev-py39.tar.gz | docker load
```

## Run Simulation

```bash
## Start a "screen"
screen
make run-step-1 FIDELITY=lowest # 2 mins
make run-step-1 FIDELITY=high   # ~hours; logs to logs/
make run-step-2
make run-step-3
make run-step-4
```

Output is written to `/mnt/persistent-disk/output/fidelity-<level>/`.

## Retrieve Results

```bash
# From your local machine:
gcloud compute scp --recurse \
    --tunnel-through-iap --zone us-central1-a \
    flowunsteady:/mnt/persistent-disk/flowunsteady_output ./flowunsteady_output
```

To sync to GCS after each step (recommended for spot instances):

```bash
# Authenticate with storage write access (required — default GCE service account has read-only storage scope)
gcloud auth login --update-adc

while true; do
    gsutil -m rsync -r /mnt/persistent-disk/flowunsteady_output gs://flowunsteady-$(gcloud config get-value project)/flowunsteady_output
    sleep 120
done

flowunsteady-flowunsteady/flowunsteady_output/fidelity-high/rotorhover/
gsutil ls gs://flowunsteady-flowunsteady/flowunsteady_output/fidelity-high/rotorhover/loading_*.*


```

## Cleanup

```bash
# Delete instance and data disk (sync to GCS first)
gcloud compute instances delete flowunsteady --zone us-central1-a
gcloud compute disks delete flowunsteady-data --zone us-central1-a

gcloud compute instances delete flowunsteady --zone us-central1-a

# Remove bucket and all contents (irreversible — download data first)
gsutil -m rm -r gs://flowunsteady-$(gcloud config get-value project)
```
