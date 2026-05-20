# Architecture — Student Variant

## High-Level Architecture

```mermaid
graph TB
    subgraph "Internet"
        User[User Browser]
        Admin[Admin/Student<br/>SSH Client]
    end

    subgraph "VPC 10.0.0.0/24 - us-east-1"
        subgraph "ALB_Layer - Public"
            subgraph "ALB Subnet AZ-A<br/>10.0.0.0/27"
                ALB1[ALB Node]
            end
            subgraph "ALB Subnet AZ-B<br/>10.0.0.32/27"
                ALB2[ALB Node]
            end
        end

        subgraph "APP_Layer - Private"
            subgraph "APP Subnet AZ-A<br/>10.0.0.64/27"
                EC2_1[EC2 Instance<br/>Apache HTTPD<br/>stress-ng]
            end
            subgraph "APP Subnet AZ-B<br/>10.0.0.96/27"
                EC2_2[EC2 Instance<br/>Apache HTTPD<br/>stress-ng]
            end
        end

        subgraph "Services_Layer - Public"
            subgraph "Services Subnet AZ-A<br/>10.0.0.128/27"
                Bastion[Bastion Host<br/>t3.micro]
                NAT[NAT Gateway]
            end
        end

        IGW[Internet Gateway]
    end

    subgraph "Auto Scaling"
        ASG[ASG<br/>min:2 max:4 desired:2<br/>Target Tracking 70% CPU]
    end

    subgraph "Notifications"
        SNS[SNS Topic<br/>Launch/Terminate emails]
    end

    subgraph "State Management"
        S3[S3 Bucket<br/>Terraform State]
        DDB[DynamoDB<br/>State Locking]
    end

    User -->|HTTP:80| ALB1
    User -->|HTTP:80| ALB2
    Admin -->|SSH:22| Bastion
    Bastion -->|SSH:22| EC2_1
    Bastion -->|SSH:22| EC2_2
    ALB1 -->|HTTP:80| EC2_1
    ALB2 -->|HTTP:80| EC2_2
    EC2_1 -->|outbound| NAT
    EC2_2 -->|outbound| NAT
    NAT --> IGW
    ASG --> EC2_1
    ASG --> EC2_2
    ASG -->|notifications| SNS
```

## Network Flow

```mermaid
sequenceDiagram
    participant User
    participant ALB
    participant EC2
    participant ASG

    User->>ALB: HTTP request (ALB DNS name)
    ALB->>EC2: HTTP:80 (health check passed)
    EC2-->>ALB: 200 OK + instance-id + AZ
    ALB-->>User: Response

    Note over ASG,EC2: Target Tracking Scaling
    Note over ASG: CPU > 70% avg → scale-out
    ASG->>EC2: Launch new instance
    Note over ASG: CPU < 70% avg (sustained) → scale-in
    ASG->>EC2: Terminate excess instance
```

## Security Layers

```mermaid
graph LR
    subgraph "NACLs - Stateless"
        NACL_ALB[ALB NACL<br/>HTTP:80 in from 0.0.0.0/0]
        NACL_APP[APP NACL<br/>HTTP:80 in from ALB subnets<br/>SSH:22 in from Services subnet]
        NACL_SVC[Services NACL<br/>SSH:22 in from 0.0.0.0/0]
    end

    subgraph "Security Groups - Stateful"
        SG_ALB[ALB SG<br/>HTTP:80 in from 0.0.0.0/0]
        SG_APP[APP SG<br/>HTTP:80 in from ALB SG<br/>SSH:22 in from Bastion SG]
        SG_Bastion[Bastion SG<br/>SSH:22 in from 0.0.0.0/0<br/>SSH:22 out to APP SG]
    end

    NACL_ALB --> SG_ALB
    NACL_APP --> SG_APP
    NACL_SVC --> SG_Bastion
```

## Subnet Layout

| Subnet | CIDR | AZ | Type | Purpose |
|--------|------|-----|------|---------|
| ALB-1 | 10.0.0.0/27 | us-east-1a | Public | ALB |
| ALB-2 | 10.0.0.32/27 | us-east-1b | Public | ALB |
| APP-1 | 10.0.0.64/27 | us-east-1a | Private | Web servers |
| APP-2 | 10.0.0.96/27 | us-east-1b | Private | Web servers |
| Services | 10.0.0.128/27 | us-east-1a | Public | NAT Gateway + Bastion |

## Key Design Decisions

- **Three-layer subnet architecture**: ALB, APP, and Services layers with dedicated NACLs for defense-in-depth
- **Single NAT Gateway**: Cost optimization — one NAT in Services subnet serves both APP subnets
- **Bastion host**: SSH access to private instances without requiring EC2 Instance Connect permissions
- **Target Tracking scaling**: AWS-managed scaling at 70% CPU target, reacts in 1-5 minutes
- **Unlimited CPU credits**: t3.micro instances can burst to 100% immediately for stress testing
- **Shared key pair**: Same SSH key for bastion and APP instances (stored in SSM Parameter Store)
