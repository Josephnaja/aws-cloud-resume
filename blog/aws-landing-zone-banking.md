# Secure Multi-Account AWS Landing Zone for French Banking Compliance

Building a production-grade AWS Landing Zone for financial services requires balancing strict regulatory requirements with practical cloud architecture. Here's how I designed and implemented a multi-account landing zone targeting DORA and RGPD compliance for French banking institutions.

## The Challenge

French banks operating on AWS must satisfy two primary regulatory frameworks:

- **DORA** (Digital Operational Resilience Act) — requires comprehensive audit trails, tested disaster recovery, continuous threat detection, and third-party ICT risk management
- **RGPD/GDPR** — imposes strict EU data residency, encryption at rest and in transit, least-privilege access controls, and demonstrable data protection

Rather than retrofitting compliance onto individual applications, I built a landing zone that enforces these controls at the platform level — making compliance a platform guarantee, not a per-application burden.

## Architecture Overview

### Multi-Account Structure

The landing zone uses AWS Organizations with seven dedicated accounts across four Organizational Units:

![AWS Organizations Architecture](blog/aws-landing-zone-org.png)

**Key design choices:**
- **Management Account** — hosts Organizations, SCPs, IAM Identity Center, and KMS/Encryption
- **Security OU** — Security Account (GuardDuty, Security Hub, Config) and Log Archive Account (CloudTrail, Config, VPC Flow Logs)
- **Infrastructure OU** — Shared Services Account (Transit Gateway, VPN, Direct Connect, Egress VPC)
- **Workload OU** — Production (10.1.0.0/16), Staging (10.2.0.0/16), Dev (10.3.0.0/16) each in their own child OU
- **Sandbox OU** — Experimentation with restricted guardrails

### Network Architecture

All traffic flows through a hub-and-spoke topology with Transit Gateway at the center:

![Network Architecture - Primary and DR Regions](blog/aws-landing-zone-network.png)

**Key elements:**
- **Dual-path hybrid connectivity** — Direct Connect (primary) and Site-to-Site VPN (backup) with automatic BGP failover
- **Three isolated TGW route tables** — Production and Non-Production cannot reach each other; Shared Services routes to all
- **Centralized egress** — All outbound internet traffic routes through a dedicated Egress VPC with NAT Gateways
- **VPC Endpoints** — S3, DynamoDB, KMS, CloudWatch Logs, and SSM accessed privately without internet transit
- **DR Region (eu-west-1)** — Mirrored Production VPC with RDS cross-region replica and S3 cross-region replication

## Governance with Service Control Policies

Six SCPs create a compliance boundary that individual teams cannot bypass:

| SCP | What It Prevents |
|-----|-----------------|
| **Region Restriction** | Resource creation outside eu-west-3 and eu-west-1 |
| **Security Services Protection** | Disabling CloudTrail, Config, GuardDuty, or Security Hub |
| **Production Data Protection** | Deletion of KMS keys, S3 bucket policies, RDS snapshots |
| **Service Allowlist** | Usage of non-approved AWS services |
| **Encryption Enforcement** | Creation of unencrypted S3 buckets, EBS volumes, or RDS instances |
| **IAM Key Restriction** | Creation of long-lived IAM access keys |

## Security and Encryption

### Zero-Trust Network Design

Every workload VPC follows strict isolation:
- **Application subnets** (private) — route to TGW for egress via centralized NAT
- **Database subnets** (isolated) — no route to internet or NAT, completely air-gapped
- **Default security group** — deny-all ingress and egress; all traffic must be explicitly permitted

### Encryption Everywhere

- One KMS CMK per account with restricted key policies
- Account-level EBS default encryption
- S3 default SSE-KMS encryption
- RDS encryption enforced by SCP
- Automatic key rotation enabled on all CMKs

## Immutable Audit Logging

The Log Archive account provides tamper-proof audit trails:

- **S3 Object Lock** in compliance mode with 365-day retention
- **Bucket policies** denying deletion by any principal, including root
- **Organization-level CloudTrail** delivering to the centralized bucket
- **CloudWatch alarm** on trail delivery errors
- **SCP** preventing CloudTrail from being disabled

This satisfies DORA's requirement for audit trails that survive even a compromised administrator account.

## Disaster Recovery

| Metric | Target | How Achieved |
|--------|--------|--------------|
| **RTO** | 4 hours | Pre-provisioned DR VPC, RDS replica promotion, TGW route update |
| **RPO** | 1 hour | Asynchronous RDS replication, S3 cross-region replication |

The DR VPC in eu-west-1 mirrors the primary production VPC using the same Terraform module, ensuring configuration parity.

## Infrastructure as Code

The entire landing zone is codified in Terraform across 10 reusable modules:

```
terraform/
├── modules/
│   ├── organizations/          # AWS Organizations, OUs, accounts, SCPs
│   ├── networking/             # Transit Gateway, route tables, peering
│   ├── hybrid-connectivity/    # Direct Connect, VPN, BGP config
│   ├── workload-vpc/           # Reusable VPC (app + db subnets, endpoints)
│   ├── egress-vpc/             # Centralized NAT/egress VPC
│   ├── security/               # Security Hub, GuardDuty, Config aggregation
│   ├── logging/                # CloudTrail org trail, S3 buckets, Object Lock
│   ├── identity/               # IAM Identity Center, permission sets
│   ├── encryption/             # KMS keys, EBS default encryption
│   └── disaster-recovery/      # DR region VPC, RDS replica, S3 replication
├── environments/               # 8 per-account configurations
└── tests/                      # Terratest integration tests
```

A **simulation mode** allows the full architecture to run in a single AWS account for testing, making it practical without enterprise infrastructure.

## Key Takeaways

1. **Compliance as code** — SCPs and encryption defaults make non-compliance impossible at the platform level
2. **Network isolation by design** — Transit Gateway route table segmentation prevents lateral movement between environments
3. **Immutable logging** — S3 Object Lock in compliance mode creates audit trails that even root cannot delete
4. **Modular IaC** — Reusable Terraform modules enable consistent deployments across accounts and regions
5. **Practical DR** — Pre-provisioned infrastructure with asynchronous replication achieves banking-grade RTO/RPO targets

---

*Technologies: Terraform, AWS Organizations, Transit Gateway, KMS, Security Hub, GuardDuty, CloudTrail, Direct Connect, S3 Object Lock*

*Compliance: DORA, RGPD/GDPR | Regions: eu-west-3 (Paris), eu-west-1 (Ireland)*
