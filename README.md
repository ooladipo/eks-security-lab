# 🔐 EKS Security Lab

A hands-on AWS EKS security lab focused on implementing and validating **defence-in-depth security controls** across Kubernetes networking, workload identity, authorization, and secrets management.

The goal is to build a realistic EKS environment, deliberately test security boundaries, verify that controls are actually enforced, and document the results.

---

## 🎯 Objectives

This lab demonstrates practical implementation of:

* AWS VPC and private networking
* Amazon EKS
* Managed Kubernetes worker nodes
* Kubernetes Services
* AWS Load Balancer exposure
* Kubernetes NetworkPolicy
* EKS Pod Identity
* AWS IAM least privilege
* Kubernetes RBAC
* Kubernetes Secrets security
* Workload-level authorization testing
* Defence-in-depth security principles

The environment is built incrementally using:

* Terraform
* AWS CLI
* Kubernetes manifests
* kubectl
* PowerShell
* Git / GitHub

---

# 🏗️ Architecture

```text
                         Internet
                            │
                            ▼
                  AWS Load Balancer
                            │
                            ▼
                  ┌──────────────────┐
                  │    Amazon EKS    │
                  │                  │
                  │  Kubernetes API  │
                  │                  │
                  │  Private Worker  │
                  │     Nodes        │
                  │                  │
                  │  ┌────────────┐  │
                  │  │   Nginx    │  │
                  │  │   Pods     │  │
                  │  └────────────┘  │
                  │                  │
                  │ NetworkPolicy    │
                  │ RBAC             │
                  │ Pod Identity     │
                  │ Secrets          │
                  └──────────────────┘
                            │
                            ▼
                       AWS IAM
                            │
                            ▼
                       Amazon S3
```

The EKS worker nodes are deployed into private subnets across multiple Availability Zones.

---

# 🏗️ Infrastructure

## VPC

The lab uses a dedicated VPC containing:

* Public subnets
* Private subnets
* Internet Gateway
* NAT Gateway
* Public route tables
* Private route tables
* Multi-AZ subnet deployment

Worker nodes run in private subnets and use the NAT Gateway for outbound Internet access.

### Security objective

Reduce direct Internet exposure of Kubernetes worker nodes while maintaining required outbound connectivity.

---

# ☸️ Amazon EKS

The lab uses Amazon EKS with Kubernetes:

```text
Version: 1.36
```

The cluster includes:

* Managed node group
* Worker nodes in private subnets
* Kubernetes API endpoint
* EKS control-plane logging

Enabled control-plane logs:

* API
* Audit
* Authenticator

The current lab configuration has both private and public Kubernetes API endpoint access enabled.

---

# 🖥️ Worker Nodes

The EKS managed node group provides the compute capacity on which Kubernetes workloads run.

Conceptually:

```text
EKS Control Plane
       │
       │ schedules workloads
       ▼
┌───────────────────────┐
│   Worker Node         │
│                       │
│  ┌───────┐ ┌───────┐  │
│  │ Nginx │ │ Nginx │  │
│  │  Pod  │ │  Pod  │  │
│  └───────┘ └───────┘  │
└───────────────────────┘
```

The worker nodes are EC2 instances managed through an EKS managed node group.

---

# 🌐 Kubernetes Networking

## Nginx Application

A simple Nginx workload was deployed to validate Kubernetes scheduling and networking.

The application was exposed internally using a Kubernetes `ClusterIP` Service.

Connectivity was verified from another Kubernetes workload using:

```text
curl http://server
```

The Nginx application successfully returned an HTTP response.

---

# ⚖️ AWS Load Balancer

The Nginx Service was subsequently exposed using:

```yaml
type: LoadBalancer
```

AWS provisioned an external load balancer for the Kubernetes Service.

This demonstrated the difference between:

```text
ClusterIP
    │
    └── Internal Kubernetes access

LoadBalancer
    │
    └── External AWS load balancing
```

---

# 🌐 Kubernetes NetworkPolicy

NetworkPolicy was implemented to restrict pod-to-pod communication.

## Default Deny

A default-deny ingress policy was created for the lab namespace.

Before the policy:

```text
Client ────────────────> Server
          ALLOWED
```

After applying the default-deny policy:

```text
Client ────────X────────> Server
          DENIED
```

The connection attempt timed out, demonstrating that the NetworkPolicy was being enforced.

## Explicit Allow

A second NetworkPolicy was created to allow the client workload to communicate with the server.

The allowed traffic was:

```text
Client ───── HTTP:80 ─────> Server
              │
              ▼
           ALLOWED
```

Testing demonstrated:

| Traffic                 | Result    |
| ----------------------- | --------- |
| Client → Server port 80 | ✅ Allowed |
| Client → Server port 81 | ❌ Denied  |

### Security objective

NetworkPolicy reduces unnecessary east-west communication and helps limit lateral movement after a workload compromise.

---

# 🔑 EKS Pod Identity

EKS Pod Identity was implemented to provide AWS permissions directly to a Kubernetes workload without distributing static AWS credentials.

The EKS Pod Identity Agent was installed as an EKS add-on.

Architecture:

```text
Kubernetes Pod
      │
      ▼
ServiceAccount
      │
      ▼
EKS Pod Identity
      │
      ▼
IAM Role
      │
      ▼
Amazon S3
```

The workload was associated with the IAM role:

```text
eks-security-lab-pod-s3-reader
```

The workload successfully obtained temporary AWS credentials.

The assumed identity was verified using:

```powershell
aws sts get-caller-identity
```

---

# 🛡️ IAM Least Privilege

The Pod Identity workload was intentionally given limited S3 permissions.

The workload was permitted to read the test object:

```text
s3:GetObject
```

Testing:

```text
Read permitted S3 object
        ↓
      ALLOWED
```

The workload was not given permission to list all S3 buckets.

Testing:

```text
s3:ListAllMyBuckets
        ↓
      DENIED
```

### Security objective

A compromised workload should receive only the AWS permissions required for its legitimate function.

This reduces the potential AWS blast radius of a workload compromise.

---

# 👤 Kubernetes RBAC

Kubernetes RBAC was implemented to control what workloads can do through the Kubernetes API.

A dedicated ServiceAccount was created:

```text
pod-reader
```

A namespace-scoped Role was created with the following permissions:

```text
pods:
  get
  list
  watch
```

The Role was connected to the ServiceAccount using a RoleBinding.

Architecture:

```text
ServiceAccount
      │
      ▼
RoleBinding
      │
      ▼
Role
      │
      ├── get pods
      ├── list pods
      └── watch pods
```

## RBAC Testing

Authorization was explicitly tested using:

```text
kubectl auth can-i
```

Results:

| Action      | Result    |
| ----------- | --------- |
| Get pods    | ✅ Allowed |
| List pods   | ✅ Allowed |
| Watch pods  | ✅ Allowed |
| Create pods | ❌ Denied  |
| Delete pods | ❌ Denied  |

The permissions were also tested from inside a running Kubernetes workload.

The workload attempted to:

```text
Create another pod
Delete its own pod
```

Both operations were rejected by the Kubernetes API.

Example:

```text
User "system:serviceaccount:rbac-lab:pod-reader"
cannot delete resource "pods"
```

### Security objective

Prevent a compromised workload from obtaining unnecessary control over Kubernetes resources.

---

# 🔐 Kubernetes Secrets

A Kubernetes Secret was created to demonstrate sensitive configuration handling and fine-grained access control.

The test Secret contained application configuration values such as:

```text
DB_USERNAME
DB_PASSWORD
```

The lab uses non-production test credentials. Sensitive values are intentionally excluded from source control and documentation.

---

## Base64 Is Not Encryption

The Secret data was inspected and the Base64-encoded value was successfully decoded.

This demonstrated:

```text
Base64
   ≠
Encryption
```

Anyone with sufficient permission to read a Kubernetes Secret can retrieve the encoded data and decode it.

Therefore, simply storing a value inside a Kubernetes Secret does not eliminate the need for strong access controls.

---

# 🔐 Fine-Grained Secret RBAC

A dedicated ServiceAccount was created:

```text
secret-reader
```

It was bound to a namespace-scoped Role that allows:

```text
GET app-secret
```

The Role uses `resourceNames` to restrict access to the specific Secret:

```yaml
resources:
  - secrets

resourceNames:
  - app-secret

verbs:
  - get
```

This means the workload does not receive broad access to all Secrets.

Conceptually:

```text
secret-reader
      │
      ├── GET app-secret       ✅
      ├── GET other Secret    ❌
      ├── LIST Secrets        ❌
      └── DELETE app-secret   ❌
```

---

# 🧪 Workload-Level Secret Testing

The authorization was tested from inside an actual Kubernetes workload running with the `secret-reader` ServiceAccount.

The workload successfully retrieved the permitted Secret:

```text
GET app-secret
     ↓
   ALLOWED
```

The workload was unable to:

```text
GET another Secret
        ↓
      DENIED

LIST Secrets
        ↓
      DENIED

DELETE app-secret
        ↓
      DENIED
```

The workload successfully retrieved the permitted Secret data through the Kubernetes API and the Base64 value was decoded successfully.

### Security scenario

This simulates a compromised workload:

```text
Attacker
   │
   ▼
Compromised Workload
   │
   ▼
ServiceAccount
   │
   ▼
Kubernetes API
   │
   ▼
RBAC
   │
   ├── Required Secret → ✅
   ├── Other Secrets   → ❌
   ├── Secret Listing   → ❌
   └── Secret Deletion  → ❌
```

### Security objective

Limit the blast radius of a compromised workload by restricting access to only the Kubernetes resources and Secrets required by that workload.

---

# ⚠️ Secret Management Considerations

Kubernetes Secret security should consider more than simply creating a `Secret` object.

Important considerations include:

* RBAC
* Encryption at rest
* Secret rotation
* External secret-management systems
* Avoiding plaintext credentials in Git
* Avoiding credentials in application manifests
* Restricting Secret access to required workloads
* Monitoring access to sensitive resources

The lab Secret manifest containing test credentials is intentionally excluded from Git using `.gitignore`.

---

# 🛡️ Defence-in-Depth

The lab demonstrates multiple independent security layers.

```text
                         Internet
                            │
                            ▼
                    AWS Load Balancer
                            │
                            ▼
                     Amazon EKS
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
       NetworkPolicy       RBAC       Pod Identity
             │              │              │
             ▼              ▼              ▼
        Pod traffic      K8s API        AWS IAM
                                           │
                                           ▼
                                          S3
```

Each layer answers a different security question.

| Security Control      | Security Question                                   |
| --------------------- | --------------------------------------------------- |
| VPC / Private Subnets | Where can infrastructure be reached from?           |
| Security Groups       | Which network connections are permitted?            |
| NetworkPolicy         | Which workloads can communicate?                    |
| Kubernetes RBAC       | What can a workload do inside Kubernetes?           |
| EKS Pod Identity      | What can a workload do in AWS?                      |
| IAM Least Privilege   | Which AWS actions/resources are permitted?          |
| Secrets + RBAC        | Which workloads can access sensitive configuration? |

---

# 🧪 Security Testing Methodology

Each control is implemented and validated using the following process:

```text
Design
  ↓
Implement
  ↓
Deploy
  ↓
Test expected behaviour
  ↓
Attempt unauthorized behaviour
  ↓
Verify enforcement
  ↓
Document results
```

The objective is not simply to configure a security control but to provide evidence that the control is actually enforced.

---

# 💥 Threat Model

The lab assumes that an attacker may eventually compromise a Kubernetes workload.

The security objective is therefore not simply:

> Prevent every compromise.

Instead, the objective is:

> **Limit what an attacker can do after compromise.**

Examples demonstrated in the lab:

### Network compromise

```text
Compromised Pod
      │
      ▼
NetworkPolicy
      │
      └── Unauthorized pod communication → ❌
```

### Kubernetes API compromise

```text
Compromised Pod
      │
      ▼
ServiceAccount
      │
      ▼
RBAC
      │
      └── Unauthorized Kubernetes actions → ❌
```

### AWS compromise

```text
Compromised Pod
      │
      ▼
Pod Identity
      │
      ▼
IAM
      │
      └── Unauthorized AWS actions → ❌
```

### Secret compromise

```text
Compromised Pod
      │
      ▼
ServiceAccount
      │
      ▼
RBAC
      │
      ├── Required Secret → ✅
      └── Other Secrets   → ❌
```

This demonstrates **blast-radius reduction through layered least privilege**.

---

# 📁 Repository Structure

```text
eks-security-lab/
│
├── eks.tf
├── iam.tf
├── versions.tf
├── pod-identity.tf
│
├── network-policy-allow.yaml
├── network-policy-client.yaml
├── network-policy-deny.yaml
├── network-policy-test.yaml
│
├── pod-identity-serviceaccount.yaml
├── pod-identity-test.yaml
│
├── rbac-lab.yaml
├── rbac-serviceaccount.yaml
├── rbac-role.yaml
├── rbac-rolebinding.yaml
├── rbac-test-pod.yaml
│
├── secrets-lab.yaml
├── secret-reader-serviceaccount.yaml
├── secret-reader-role.yaml
├── secret-reader-rolebinding.yaml
├── secret-reader-test-pod.yaml
│
├── test-object.txt
├── .gitignore
└── README.md
```

The local `secrets-demo.yaml` file contains test credentials and is intentionally excluded from source control.

---

# 📌 Git Checkpoints

Major security milestones are committed separately to maintain a clear project history.

| Commit    | Milestone                                     |
| --------- | --------------------------------------------- |
| `9423f5f` | Add NAT gateway for private EKS networking    |
| `cf997a2` | Add EKS managed node group                    |
| `d050c4e` | Deploy Nginx application and internal service |
| `2821356` | Expose Nginx using AWS LoadBalancer           |
| `865c366` | Add Kubernetes NetworkPolicy isolation lab    |
| `6d27055` | Implement EKS Pod Identity least privilege    |
| `9a5072d` | Implement Kubernetes RBAC least privilege     |

---

# 🚧 Planned Security Enhancements

Future stages of the lab will explore additional EKS security controls and attack scenarios.

Planned areas include:

* EKS API endpoint hardening
* Kubernetes Secrets hardening
* Encryption at rest
* EKS audit logging analysis
* Security monitoring
* Security Group analysis
* Workload compromise simulation
* Kubernetes privilege escalation scenarios
* Lateral movement testing
* Additional IAM hardening
* Container security
* Admission control
* Runtime security
* Final security architecture review
* Security control assessment

---

# 🎓 Security Principles Demonstrated

## Least Privilege

Identities and workloads receive only the permissions required for their function.

## Defence in Depth

Multiple independent security controls reduce reliance on a single defensive layer.

## Zero Trust

Workloads are not automatically trusted simply because they are running inside the cluster.

## Blast Radius Reduction

A compromised workload should have limited access to Kubernetes resources, other workloads, AWS services, and sensitive data.

## Continuous Validation

Security controls are tested through both permitted and deliberately unauthorized actions.

---

# 🧰 Technologies

* AWS
* Amazon EKS
* Kubernetes
* Terraform
* AWS IAM
* Amazon S3
* AWS VPC
* AWS NAT Gateway
* AWS Load Balancer
* Kubernetes NetworkPolicy
* Kubernetes RBAC
* Kubernetes Secrets
* PowerShell
* kubectl
* AWS CLI
* Git
* GitHub

---

# 🎯 Project Goal

The ultimate goal of this project is to demonstrate how a production-style Amazon EKS environment can be protected using **layered security controls and least-privilege principles**.

Rather than simply deploying infrastructure, the project focuses on:

1. Building the environment.
2. Implementing security controls.
3. Testing expected behaviour.
4. Attempting unauthorized actions.
5. Verifying that security boundaries are enforced.
6. Documenting the evidence.
7. Maintaining a reproducible Git history.

This makes the project a practical demonstration of **cloud and Kubernetes security engineering**, rather than a purely theoretical Kubernetes exercise.
