# Healthcare Security Platform

HIPAA-compliant patient records management system with multi-layer encryption, AI-powered PII detection, and comprehensive audit logging.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
  - [Stage 00: Foundation](#stage-00-foundation)
  - [Stage 01: KMS Keys](#stage-01-kms-keys)
  - [Stage 02: DynamoDB](#stage-02-dynamodb)
  - [Stage 03: Parameter Store](#stage-03-parameter-store)
  - [Stage 04: Lambda Functions](#stage-04-lambda-functions)
  - [Stage 05: API Gateway](#stage-05-api-gateway)
  - [Stage 06: Bedrock Integration](#stage-06-bedrock-integration)
  - [Stage 07: CloudTrail and S3 Logging](#stage-07-cloudtrail-and-s3-logging)
  - [Stage 08: Athena](#stage-08-athena)
  - [Stage 09: Monitoring and Alerts](#stage-09-monitoring-and-alerts)
- [Security Features](#security-features)
- [Cost Estimate](#cost-estimate)
- [Cleanup](#cleanup)

## Overview

This project demonstrates enterprise-grade AWS security architecture for healthcare data. It implements defense-in-depth principles with multiple layers of encryption, real-time PII detection using Amazon Bedrock, and comprehensive audit logging for compliance.

### Key Features

- **Multi-layer encryption**: Client-side encryption with KMS customer-managed keys and encryption context for per-patient data isolation
- **AI-powered security**: Amazon Bedrock with Claude for PII detection and Guardrails for policy enforcement
- **Comprehensive audit trail**: CloudTrail logging to S3 with Athena queries for compliance reporting
- **Real-time threat detection**: EventBridge rules triggering SNS alerts for security events
- **Infrastructure as Code**: 100% Terraform with modular, reusable components

## Architecture
```mermaid
flowchart TB
    subgraph Client
        A[Healthcare Application]
    end

    subgraph API Layer
        B[API Gateway]
    end

    subgraph Compute Layer
        C[Lambda Functions]
    end

    subgraph Security Layer
        D[KMS - DynamoDB Key]
        E[KMS - S3 Logs Key]
        F[KMS - Parameter Store Key]
        G[Parameter Store]
    end

    subgraph Data Layer
        H[DynamoDB - Patient Records]
    end

    subgraph AI Layer
        I[Amazon Bedrock]
        J[Bedrock Guardrails]
    end

    subgraph Audit Layer
        K[CloudTrail]
        L[S3 - Audit Logs]
        M[Athena]
    end

    subgraph Monitoring Layer
        N[EventBridge]
        O[SNS Alerts]
    end

    A -->|HTTPS| B
    B -->|Invoke| C
    C -->|Encrypt/Decrypt| D
    C -->|Get Secrets| G
    G -.->|Encrypted by| F
    C -->|Read/Write| H
    H -.->|Encrypted by| D
    C -->|PII Detection| I
    I -->|Policy Check| J
    C -->|API Calls| K
    K -->|Store Logs| L
    L -.->|Encrypted by| E
    L -->|Query| M
    K -->|Events| N
    N -->|Alert| O
```

### Data Flow: Create Patient Record
```mermaid
sequenceDiagram
    participant Client
    participant API Gateway
    participant Lambda
    participant Parameter Store
    participant KMS
    participant Bedrock
    participant DynamoDB
    participant CloudTrail

    Client->>API Gateway: POST /patients
    API Gateway->>Lambda: Invoke
    Lambda->>Parameter Store: Get KMS Key ID
    Parameter Store-->>Lambda: Key ID (decrypted)
    Lambda->>Bedrock: Detect PII in notes
    Bedrock-->>Lambda: Sanitized notes
    Lambda->>KMS: GenerateDataKey (with encryption context)
    KMS-->>Lambda: Data key
    Lambda->>Lambda: Encrypt patient data
    Lambda->>DynamoDB: PutItem (encrypted)
    DynamoDB-->>Lambda: Success
    Lambda-->>API Gateway: 200 OK
    API Gateway-->>Client: Patient created
    Note over CloudTrail: All API calls logged
```

## Project Structure
```
healthcare-security-platform/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── providers.tf      # AWS provider and S3 backend
│   │       ├── main.tf           # Module calls
│   │       └── outputs.tf        # Environment outputs
│   └── modules/
│       ├── kms/                  # KMS keys for encryption
│       ├── dynamodb/             # Patient records table
│       ├── parameter-store/      # Secrets management
│       ├── lambda/               # Lambda functions
│       ├── api-gateway/          # REST API
│       ├── bedrock/              # AI integration
│       ├── cloudtrail/           # Audit logging
│       ├── s3-logging/           # Log storage
│       ├── athena/               # Compliance queries
│       └── monitoring/           # Alerts and dashboards
├── lambda-functions/             # Lambda source code
├── docs/                         # Additional documentation
└── scripts/                      # Deployment and utility scripts
```

## Prerequisites

Before deploying this project, you need:

1. **AWS Account** with administrator access
2. **AWS CLI** configured with credentials
3. **Terraform** version 1.5.0 or later
4. **Git** for version control

### AWS Account Setup

This project uses AWS Organizations with a dedicated member account:

| Account | Purpose |
|---------|---------|
| Management Account | AWS Organizations, billing, governance |
| Healthcare-Security-Dev | All project resources |

### Required Permissions

The IAM user or role running Terraform needs permissions for:
- KMS (create keys, manage policies)
- DynamoDB (create tables)
- Lambda (create functions)
- API Gateway (create APIs)
- S3 (create buckets)
- CloudTrail (create trails)
- Bedrock (invoke models, create guardrails)
- IAM (create roles and policies)
- SSM Parameter Store (create parameters)
- SNS (create topics)
- EventBridge (create rules)
- Athena (create databases and workgroups)

## Deployment Guide

### Initial Setup

1. Clone the repository:
```bash
git clone https://github.com/jbray1992/healthcare-security-platform.git
cd healthcare-security-platform
```

2. Create the Terraform backend (one-time manual setup):
```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket healthcare-tfstate-<ACCOUNT_ID> \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket healthcare-tfstate-<ACCOUNT_ID> \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket healthcare-tfstate-<ACCOUNT_ID> \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name healthcare-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

3. Update the backend configuration in `terraform/environments/dev/providers.tf` with your bucket name.

---

### Stage 00: Foundation

**Status**: ✅ Complete

**What it creates**:
- S3 bucket for Terraform state (manual)
- DynamoDB table for state locking (manual)

**Files**: None (manual setup)

---

### Stage 01: KMS Keys

**Status**: ✅ Complete

**What it creates**:
- KMS key for DynamoDB patient records encryption
- KMS key for S3 CloudTrail logs encryption
- KMS key for Parameter Store secrets encryption
- KMS aliases for each key

**Files**: 
- [terraform/modules/kms/](terraform/modules/kms/)

**Deploy**:
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

**Outputs**:
- `dynamodb_key_arn` - ARN of the DynamoDB encryption key
- `s3_logs_key_arn` - ARN of the S3 logs encryption key
- `parameter_store_key_arn` - ARN of the Parameter Store encryption key

---

### Stage 02: DynamoDB

**Status**: 🔲 Not Started

**What it creates**:
- DynamoDB table for patient records
- Server-side encryption with KMS
- Point-in-time recovery enabled

**Files**: 
- [terraform/modules/dynamodb/](terraform/modules/dynamodb/)

---

### Stage 03: Parameter Store

**Status**: 🔲 Not Started

**What it creates**:
- SecureString parameters for secrets
- KMS encryption for all parameters

**Files**: 
- [terraform/modules/parameter-store/](terraform/modules/parameter-store/)

---

### Stage 04: Lambda Functions

**Status**: 🔲 Not Started

**What it creates**:
- Lambda functions for CRUD operations
- Client-side encryption implementation
- Bedrock integration for PII detection

**Files**: 
- [terraform/modules/lambda/](terraform/modules/lambda/)
- [lambda-functions/](lambda-functions/)

---

### Stage 05: API Gateway

**Status**: 🔲 Not Started

**What it creates**:
- REST API with resource policies
- Request validation
- Lambda integrations

**Files**: 
- [terraform/modules/api-gateway/](terraform/modules/api-gateway/)

---

### Stage 06: Bedrock Integration

**Status**: 🔲 Not Started

**What it creates**:
- Bedrock Guardrails for PII filtering
- IAM permissions for Bedrock access

**Files**: 
- [terraform/modules/bedrock/](terraform/modules/bedrock/)

---

### Stage 07: CloudTrail and S3 Logging

**Status**: 🔲 Not Started

**What it creates**:
- S3 bucket for audit logs
- CloudTrail trail with KMS encryption
- S3 lifecycle policies

**Files**: 
- [terraform/modules/cloudtrail/](terraform/modules/cloudtrail/)
- [terraform/modules/s3-logging/](terraform/modules/s3-logging/)

---

### Stage 08: Athena

**Status**: 🔲 Not Started

**What it creates**:
- Athena database and workgroup
- Saved queries for compliance reporting

**Files**: 
- [terraform/modules/athena/](terraform/modules/athena/)

---

### Stage 09: Monitoring and Alerts

**Status**: 🔲 Not Started

**What it creates**:
- SNS topic for security alerts
- EventBridge rules for threat detection
- CloudWatch alarms

**Files**: 
- [terraform/modules/monitoring/](terraform/modules/monitoring/)

---

## Security Features

### Encryption

| Layer | Method | Key Type |
|-------|--------|----------|
| Data at rest (DynamoDB) | Server-side + Client-side | Customer managed KMS |
| Data at rest (S3) | Server-side | Customer managed KMS |
| Data at rest (Parameter Store) | Server-side | Customer managed KMS |
| Data in transit | TLS 1.2+ | AWS managed |

### Encryption Context

Client-side encryption uses encryption context to bind ciphertext to specific patients:
```python
encryption_context = {
    "patient_id": "P12345",
    "record_type": "medical"
}
```

Decryption fails if the context does not match, providing cryptographic isolation between patients.

### PII Detection

Amazon Bedrock scans clinical notes for:
- Social Security Numbers (blocked)
- Credit card numbers (blocked)
- Phone numbers (anonymized)
- Email addresses (anonymized)
- Physical addresses (anonymized)

### Audit Logging

CloudTrail captures all API calls including:
- KMS key usage (encrypt, decrypt, generate data key)
- DynamoDB operations (GetItem, PutItem, Query)
- Bedrock invocations
- Parameter Store access

Athena queries enable compliance reporting:
- Who accessed which patient records
- Failed decryption attempts
- Guardrail violations

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| KMS (3 keys) | $3.00 |
| DynamoDB (on-demand) | ~$0.25 |
| Lambda | Free tier |
| API Gateway | ~$0.50 |
| S3 (logs) | ~$0.15 |
| CloudTrail | ~$2.00 |
| Bedrock | ~$0.50 |
| Athena | ~$0.05 |
| SNS | Free tier |
| EventBridge | Free tier |
| **Total** | **~$6-8/month** |

## Cleanup

To destroy all resources:
```bash
cd terraform/environments/dev
terraform destroy
```

Note: The S3 bucket for Terraform state and DynamoDB lock table must be deleted manually since they were created outside of Terraform.
```bash
# Empty and delete state bucket
aws s3 rm s3://healthcare-tfstate-<ACCOUNT_ID> --recursive
aws s3 rb s3://healthcare-tfstate-<ACCOUNT_ID>

# Delete lock table
aws dynamodb delete-table --table-name healthcare-terraform-lock
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Author

Jordan Bray - [GitHub](https://github.com/jbray1992) | [LinkedIn](https://www.linkedin.com/in/jordanbray1992/)
