---

# 🧬 MSI & TMB AWS Batch Pipeline

A **Nextflow-based pipeline for MSI (Microsatellite Instability) and TMB (Tumor Mutational Burden)** calculation using **AWS Batch** with EC2 compute environments.
Designed for **WES/WGS DNA data** to generate **biomarker reports** in a scalable cloud environment.

---

## 📖 About

This repository provides a complete setup to run **MSI and TMB calculations** on WES/WGS DNA data using **Nextflow** and **AWS Batch**.

**MSI (Microsatellite Instability)** detects **length changes in microsatellite repeats** in tumor DNA.
**TMB (Tumor Mutational Burden)** measures **somatic mutations per megabase** of the genome. Both biomarkers are widely used in cancer research and precision oncology.

This pipeline automates:

* MSI scoring using **MSIsensor-pro**
* TMB calculation using **VCF-based workflows** (vcf2maf or custom scripts)

---

## ⚙️ Prerequisites

| Tool                                                                                        | Description                                             |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | Manage AWS resources                                    |
| [Docker](https://www.docker.com/get-docker/)                                                | Build and push your container image                     |
| [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html)                             | Run the pipeline                                        |
| AWS Account                                                                                 | With permissions for S3, Batch, ECR, IAM, and VPC setup |
| Reference Genome                                                                            | e.g., hg38.fa for alignment and MSI calculation         |
| WES/WGS Data                                                                                | BAM or VCF files of tumor (and optional normal)         |

---

## 3. How It Works

1. **Input staging**: FASTQ/BAM/VCF files are loaded via Nextflow channels (`Channel.fromPath()`), which can handle both **local and S3 files**.
2. **MSI Calculation**: `msisensor-pro` analyzes microsatellite regions and outputs an **MSI score and status** (MSI-H, MSI-L, MSS).
3. **TMB Calculation**: Somatic variants are filtered (exonic/nonsynonymous) and **mutations per Mb** are calculated per sample.
4. **Report Generation**: Results are written to structured directories:

```
results/
 ├── msi/     # MSI reports
 └── tmb/     # TMB reports
```

5. **Scalable execution**: Each sample runs independently on **AWS Batch EC2 instances**, with outputs staged back to **S3**.

---

## 4. Technical Details

* **Nextflow Channels**:
  *Converts input paths into processable streams.*
  Supports **parallel execution** and **remote file staging** from S3.

* **Docker Containers**:
  Separate containers for **MSI** and **TMB**, pre-installed with required tools:

  * MSI: `msisensor-pro`, `samtools`, `AWS CLI`
  * TMB: Python 3, custom TMB calculation scripts, `AWS CLI`

* **AWS Batch Profiles**:

  * Queue: `nextflow8`
  * Resource allocation: 4 CPUs, 10 GB RAM

* **Why EC2?**
  Provides **flexible compute types**, supports larger genomes, and allows **long-running jobs** beyond Fargate limitations.

---

## 5. AWS Infrastructure Setup

### Compute Environment (EC2)

* Create via **AWS CLI** or **Console** (Managed, EC2 type, select instance types, VPC, subnets, IAM roles)

### Job Queue

* Associate the compute environment with a **job queue**
* Set priority and allow jobs to scale according to **maxvCpus**

### IAM Roles

* EC2 Role: `ecsInstanceRole`
* Policies:

  * `AmazonEC2ContainerServiceforEC2Role`
  * `AmazonEC2ContainerRegistryReadOnly`
  * `AmazonSSMManagedInstanceCore`
  * Optional: `AmazonS3FullAccess`

---

## 6. Build & Push Docker Images

**MSI Container**

```bash
sudo docker build --no-cache -t msi .
aws ecr create-repository --repository-name msi --region us-east-1
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com
docker tag msi:latest <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/msi:latest
docker push <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/msi:latest
```

**TMB Container**

```bash
sudo docker build --no-cache -t tmb-micromamba .
aws ecr create-repository --repository-name tmb-micromamba --region us-east-1
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com
docker tag tmb-micromamba:latest <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/tmb-micromamba:latest
docker push <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/tmb-micromamba:latest
```

---

## 7. Running the Pipeline

### Local Execution

```bash
nextflow run main.nf -profile local
```

### AWS Batch Execution

```bash
nextflow run main.nf -c nextflow.config -profile awsbatch -resume
```

Outputs will be staged automatically to:

```
s3://aws-batch-input-bioinformatics/msi-tmb-results/
```

---

## 8. Best Practices

| Environment | Subnet Type | Internet Access | Notes          |
| ----------- | ----------- | --------------- | -------------- |
| Development | Public      | Direct via IGW  | Simplest setup |
| Production  | Private     | Via NAT Gateway | More secure    |

* Use **multiple subnets across AZs** for **high availability**
* Adjust `maxvCpus` and instance types for **large WGS datasets**
* Monitor jobs via **AWS Batch Console → Jobs**

---

## 9. Cleanup

```bash
aws batch delete-compute-environment --compute-environment msi-tmb-ec2-env
aws batch delete-job-queue --job-queue msi-tmb-queue
aws ecr delete-repository --repository-name msi --force
aws ecr delete-repository --repository-name tmb-micromamba --force
```
