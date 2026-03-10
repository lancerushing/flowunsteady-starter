# Run on AWS

Assumes AWS CLI is installed and configured (`aws configure`).

> **For experienced users.** AWS resources continue billing until explicitly terminated.
> Spot instances may be interrupted mid-simulation with no refund for partial work.
> EBS volumes accrue charges even when the instance is stopped. Monitor your AWS billing
> dashboard and set a budget alert before proceeding.
>
> **Cost:** `c7i.16xlarge` spot in `us-west-2` runs ~$0.86/hr. EBS gp3 (2 TB) costs
> ~$0.08/GB/month (~$163/month) regardless of instance state.
> Terminate the instance **and** delete the volume when done.

## NOTICE

> These instructions are incomplete.  I switched over to GCLOUD after a few minutes (I didn't feel like messing with VPCs tonight)

## Launch Instance

```bash
# Get the latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters 'Name=name,Values=al2023-ami-2023*-x86_64' \
              'Name=state,Values=available' \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text --region us-west-2)

# Create default VPC if needed
aws ec2 create-default-vpc --region us-west-2 2>/dev/null || true

VPC_ID=$(aws ec2 describe-vpcs \
    --filters 'Name=isDefault,Values=true' \
    --query 'Vpcs[0].VpcId' --output text --region us-west-2)

# Create security group with SSH access
SG_ID=$(aws ec2 create-security-group \
    --group-name flowunsteady-sg-ssh2 \
    --description "FLOWUnsteady simulation" \
    --vpc-id $VPC_ID \
    --query GroupId --output text --region us-west-2)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 \
    --region us-west-2

# Create SSH key pair (skip if you already have one)
aws ec2 create-key-pair \
    --key-name flowunsteady-key \
    --query KeyMaterial --output text --region us-west-2 \
    > ~/.ssh/flowunsteady-key.pem
chmod 600 ~/.ssh/flowunsteady-key.pem

# Launch spot instance (~70% cheaper than on-demand; may be interrupted)
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type c7i.16xlarge \
    --key-name flowunsteady-key \
    --security-group-ids $SG_ID \
    --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
    --region us-west-2 \
    --query 'Instances[0].InstanceId' --output text)


echo "SG_ID: $SG_ID"
echo "Instance: $INSTANCE_ID"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-west-2
```

## Attach EBS Volume

Create a 2 TB gp3 volume in the **same AZ** as the instance, then attach it.

```bash
AZ=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' \
    --output text --region us-west-2)

VOLUME_ID=$(aws ec2 create-volume \
    --availability-zone $AZ \
    --size 2048 \
    --volume-type gp3 \
    --region us-west-2 \
    --query VolumeId --output text)

aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id $INSTANCE_ID \
    --device /dev/sdf \
    --region us-west-2
```

On the instance, format and mount the volume (first time only):

```bash
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir -p /ebs
sudo mount /dev/nvme1n1 /ebs

# Auto-mount on reboot
echo "$(sudo blkid -s UUID -o value /dev/nvme1n1)  /ebs  xfs  defaults  0  2" \
    | sudo tee -a /etc/fstab
```

## Connect via SSH

```bash
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text --region us-west-2)

ssh -i ~/.ssh/flowunsteady-key.pem ec2-user@$PUBLIC_IP
```

## Install Tools

```bash
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
newgrp docker   # apply group without logout
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

Edit `Makefile` to point `OUTPUT_PATH` at the EBS volume:

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
scp -r ec2-user@$PUBLIC_IP:/ebs/output ./output
```

To sync output to S3 after each step (optional but recommended for spot instances):

```bash
aws s3 sync /ebs/output s3://flowunsteady-flowunsteady/flowunsteady-output
```

## Cleanup

```bash
# Terminate instance (stops billing immediately)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-west-2
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region us-west-2

# Delete EBS volume (data will be lost — sync to S3 first)
aws ec2 delete-volume --volume-id $VOLUME_ID --region us-west-2

# Delete security group
aws ec2 delete-security-group --group-id $SG_ID --region us-west-2
```