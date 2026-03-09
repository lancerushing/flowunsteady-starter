# Run on Google Cloud

Assumes gcloud CLI is installed and authenticated (`gcloud auth login`).

> **Cost warning:** `n2-highcpu-64` in `us-central1` runs ~$2.24/hr on-demand (~$0.67/hr spot).
> Delete the instance when done.

## Create Project

```bash
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
    --machine-type n2-highcpu-32 \
    --image-family debian-12 \
    --image-project debian-cloud \
    --boot-disk-size 30GB \
    --boot-disk-type pd-ssd \
    --provisioning-model SPOT \
    --instance-termination-action STOP
```

> `n2-highcpu-64` = 64 vCPU, 64 GB RAM. If the simulation runs out of memory, use
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
```

On the instance, format and mount (first time only):

```bash
sudo mkfs -t ext4 /dev/sdb
sudo mkdir -p /ebs
sudo mount /dev/sdb /ebs

# Auto-mount on reboot
echo "$(sudo blkid -s UUID -o value /dev/sdb)  /ebs  ext4  defaults  0  2" \
    | sudo tee -a /etc/fstab
```

## Connect via IAP

No public IP or per-IP firewall rules needed — authenticates via your Google identity.

```bash
gcloud compute ssh flowunsteady --tunnel-through-iap --zone us-central1-a
```

## Install Tools

```bash
sudo apt-get update && sudo apt-get install -y docker.io git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

## Set Up Output Directory

```bash
sudo mkdir -p /ebs/output
sudo chown 1000:1000 /ebs/output   # match runner uid in container
```

## Clone and Configure

```bash
cd ~
git clone https://github.com/lancerushing/flowunsteady-starter
cd flowunsteady-starter
```

Edit `Makefile` to point `OUTPUT_PATH` at the disk:

```makefile
OUTPUT_PATH = /ebs/output
```

## Build and Prepare

```bash
make docker-build      # ~20 min (compiles Python 3.9 from source)
mkdir -p ./.julia
make prepare-julia     # ~10-30 min (downloads Julia packages)
```

## Run Simulation

```bash
make run-step-1 FIDELITY=high   # ~hours; logs to logs/
make run-step-2
make run-step-3
make run-step-4
```

Output is written to `/ebs/output/fidelity-<level>/`.

## Retrieve Results

```bash
# From your local machine:
gcloud compute scp --recurse \
    --tunnel-through-iap --zone us-central1-a \
    flowunsteady:/ebs/output ./output
```

To sync to GCS after each step (recommended for spot instances):

```bash
gsutil -m rsync -r /ebs/output gs://your-bucket/flowunsteady-output
```

## Cleanup

```bash
# Delete instance and data disk (sync to GCS first)
gcloud compute instances delete flowunsteady --zone us-central1-a
gcloud compute disks delete flowunsteady-data --zone us-central1-a
```
