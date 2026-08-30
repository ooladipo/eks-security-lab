\# EKS Security Lab



A hands-on AWS EKS security lab focused on implementing and validating \*\*defence-in-depth security controls\*\* across networking, workload identity, Kubernetes authorization, and secrets management.



The objective is to build a realistic Kubernetes environment, deliberately test security boundaries, and document the results.



\---



\## 🎯 Objectives



This lab demonstrates practical implementation of:



\* AWS VPC security and private networking

\* Amazon EKS cluster security

\* Kubernetes workload networking

\* Kubernetes NetworkPolicy

\* AWS Load Balancer exposure

\* EKS Pod Identity

\* AWS IAM least privilege

\* Kubernetes RBAC

\* Kubernetes Secrets security

\* Security testing and authorization validation

\* Defence-in-depth principles



The lab is built incrementally using \*\*Terraform, Kubernetes manifests, AWS CLI, kubectl, and Git\*\*.



\---



\# 🏗️ Architecture



```text

&#x20;                        Internet

&#x20;                           │

&#x20;                           ▼

&#x20;                 AWS Load Balancer

&#x20;                           │

&#x20;                           ▼

&#x20;                ┌────────────────────┐

&#x20;                │    Amazon EKS      │

&#x20;                │                    │

&#x20;                │  Kubernetes API    │

&#x20;                │                    │

&#x20;                │  Private Worker    │

&#x20;                │  Nodes             │

&#x20;                │                    │

&#x20;                │  ┌──────────────┐  │

&#x20;                │  │    Nginx     │  │

&#x20;                │  │    Pods      │  │

&#x20;                │  └──────────────┘  │

&#x20;                │                    │

&#x20;                │  NetworkPolicy     │

&#x20;                │  RBAC              │

&#x20;                │  Pod Identity      │

&#x20;                └────────────────────┘

&#x20;                           │

&#x20;                           ▼

&#x20;                      AWS IAM

&#x20;                           │

&#x20;                           ▼

&#x20;                        Amazon S3

```



Worker nodes run in \*\*private subnets\*\* across multiple Availability Zones.



\---



\# 🔐 Security Controls Implemented



\## 1. VPC \& Private EKS Networking



The EKS worker nodes are deployed into private subnets.



Implemented infrastructure includes:



\* VPC

\* Public subnets

\* Private subnets

\* Internet Gateway

\* NAT Gateway

\* Public and private route tables

\* Multi-AZ subnet deployment



\### Security objective



Prevent worker nodes from requiring direct inbound Internet connectivity while still allowing outbound access through the NAT Gateway.



\---



\## 2. Amazon EKS Cluster



The lab uses Amazon EKS with:



\* Kubernetes `1.36`

\* Managed node group

\* Worker nodes in private subnets

\* EKS control-plane logging enabled for:



&#x20; \* API

&#x20; \* Audit

&#x20; \* Authenticator



The EKS API endpoint currently has both private and public access enabled as part of the lab configuration.



\---



\## 3. Nginx Application



A simple Nginx workload was deployed to validate Kubernetes scheduling and networking.



Two replicas were deployed:



```text

nginx

├── Pod 1

└── Pod 2

```



The pods were successfully scheduled across the EKS worker nodes.



\---



\## 4. Kubernetes Services \& AWS Load Balancer



The Nginx application was initially exposed internally using a `ClusterIP` Service.



Connectivity was validated from another Kubernetes pod:



```text

curl http://nginx

```



The service was subsequently changed to:



```text

type: LoadBalancer

```



EKS provisioned an AWS Load Balancer and external HTTP access was successfully validated.



\### Security concept



The AWS Load Balancer provides external load balancing.



Kubernetes Services provide the internal service abstraction and routing to the application's pods.



\---



\# 🌐 5. Kubernetes NetworkPolicy



NetworkPolicy was implemented to control pod-to-pod communication.



\### Default deny



A default-deny ingress policy was created:



```text

Client ──────X──────> Server

```



The client was unable to connect to the Nginx server and the connection timed out.



\### Explicit allow rule



An allow policy was then created permitting:



```text

Client ──────HTTP:80──────> Server

```



Connectivity was successfully restored.



Testing demonstrated:



```text

client → server:80     ✅ ALLOWED

client → server:81     ❌ DENIED

```



\### Security objective



Limit lateral movement and reduce unnecessary pod-to-pod communication.



\---



\# 🔑 6. EKS Pod Identity



EKS Pod Identity was implemented to provide AWS permissions directly to a Kubernetes workload without distributing static AWS credentials.



Implemented:



\* EKS Pod Identity Agent

\* Kubernetes ServiceAccount

\* AWS IAM role

\* EKS Pod Identity Association

\* S3 bucket

\* Least-privilege IAM policy



Architecture:



```text

Kubernetes Pod

&#x20;     │

&#x20;     ▼

ServiceAccount

&#x20;     │

&#x20;     ▼

EKS Pod Identity

&#x20;     │

&#x20;     ▼

IAM Role

&#x20;     │

&#x20;     ▼

Amazon S3

```



The workload successfully obtained temporary AWS credentials.



The identity was verified using:



```text

aws sts get-caller-identity

```



The pod assumed the dedicated IAM role:



```text

eks-security-lab-pod-s3-reader

```



\---



\## 🛡️ Pod Identity Least-Privilege Test



The workload was permitted to read a specific S3 object.



Test:



```text

s3:GetObject

```



Result:



```text

✅ ALLOWED

```



The workload was not granted permission to list all S3 buckets.



Test:



```text

s3:ListAllMyBuckets

```



Result:



```text

❌ ACCESS DENIED

```



\### Security objective



A compromised workload should receive only the AWS permissions it actually requires.



\---



\# 👤 7. Kubernetes RBAC



Kubernetes RBAC was implemented to control what workloads can do through the Kubernetes API.



A dedicated ServiceAccount was created:



```text

pod-reader

```



A Role was created with only:



```text

pods:

&#x20; get

&#x20; list

&#x20; watch

```



A RoleBinding connected the ServiceAccount to the Role.



Architecture:



```text

ServiceAccount

&#x20;     │

&#x20;     ▼

RoleBinding

&#x20;     │

&#x20;     ▼

Role

&#x20;     │

&#x20;     ├── get pods

&#x20;     ├── list pods

&#x20;     └── watch pods

```



\### Authorization testing



The following tests were performed:



| Action      | Result    |

| ----------- | --------- |

| Get pods    | ✅ Allowed |

| List pods   | ✅ Allowed |

| Watch pods  | ✅ Allowed |

| Delete pods | ❌ Denied  |

| Create pods | ❌ Denied  |



The permissions were also tested \*\*from inside a running Kubernetes pod\*\* using the pod's ServiceAccount identity.



The workload attempted to delete itself and create another pod.



Both operations were rejected by the Kubernetes API with:



```text

403 Forbidden

```



\### Security objective



Prevent a compromised workload from gaining unnecessary control over Kubernetes resources.



\---



\# 🔐 8. Kubernetes Secrets



A Kubernetes Secret was created to demonstrate sensitive configuration handling.



The example Secret contains:



```text

DB\_USERNAME

DB\_PASSWORD

```



\### Base64 is not encryption



The Secret data was inspected and decoded.



For example:



```text

U3VwZXJTZWNyZXQxMjMh

```



decoded to:



```text

<redacted-test-password>

```



This demonstrates that Base64 provides \*\*encoding, not encryption\*\*.



\### RBAC protection



A dedicated ServiceAccount was created:



```text

secret-reader

```



Its Role permits:



```text

GET app-secret

```



but does not permit:



```text

GET another-secret

LIST secrets

DELETE app-secret

```



Testing produced:



| Action              | Result    |

| ------------------- | --------- |

| Get `app-secret`    | ✅ Allowed |

| Get another Secret  | ❌ Denied  |

| List Secrets        | ❌ Denied  |

| Delete `app-secret` | ❌ Denied  |



\### Security objective



Demonstrate that Secret security depends heavily on \*\*authorization and access control\*\*, not simply on the fact that an object is called a Kubernetes Secret.



\---



\# 🧪 Security Testing Methodology



Each security control is validated through an implementation and testing cycle:



```text

Design

&#x20; ↓

Implement

&#x20; ↓

Deploy

&#x20; ↓

Test expected behaviour

&#x20; ↓

Attempt unauthorized behaviour

&#x20; ↓

Verify enforcement

&#x20; ↓

Document results

```



This approach ensures that security controls are not simply configured but are \*\*demonstrably enforced\*\*.



\---



\# 🛡️ Defence-in-Depth Model



The lab demonstrates multiple independent security layers:



```text

&#x20;                   Internet

&#x20;                      │

&#x20;                      ▼

&#x20;             AWS Load Balancer

&#x20;                      │

&#x20;                      ▼

&#x20;             ┌─────────────────┐

&#x20;             │      EKS        │

&#x20;             └─────────────────┘

&#x20;                      │

&#x20;            ┌─────────┼─────────┐

&#x20;            ▼         ▼         ▼

&#x20;      NetworkPolicy   RBAC   Pod Identity

&#x20;            │         │         │

&#x20;            ▼         ▼         ▼

&#x20;       Pod traffic  K8s API    AWS IAM

&#x20;                                 │

&#x20;                                 ▼

&#x20;                                 S3

```



Each control addresses a different threat:



| Control               | Primary Security Question                  |

| --------------------- | ------------------------------------------ |

| VPC / Private Subnets | Where can infrastructure be reached from?  |

| Security Groups       | Which network connections are permitted?   |

| NetworkPolicy         | Which pods can communicate?                |

| Kubernetes RBAC       | What can a workload do inside Kubernetes?  |

| Pod Identity          | What can a workload do in AWS?             |

| IAM Least Privilege   | Which AWS resources/actions are permitted? |

| Secrets + RBAC        | Who can access sensitive configuration?    |



\---



\# 📁 Repository Structure



```text

eks-security-lab/

│

├── Terraform

│   ├── eks.tf

│   ├── iam.tf

│   ├── pod-identity.tf

│   └── versions.tf

│

├── Kubernetes

│   ├── nginx.yaml

│   ├── nginx-service.yaml

│   ├── network-policy-deny.yaml

│   ├── network-policy-allow.yaml

│   ├── network-policy-client.yaml

│   ├── network-policy-test.yaml

│   ├── pod-identity-serviceaccount.yaml

│   ├── pod-identity-test.yaml

│   ├── rbac-lab.yaml

│   ├── rbac-serviceaccount.yaml

│   ├── rbac-role.yaml

│   ├── rbac-rolebinding.yaml

│   ├── rbac-test-pod.yaml

│   ├── secrets-lab.yaml

│   ├── secrets-demo.yaml

│   ├── secret-reader-serviceaccount.yaml

│   ├── secret-reader-role.yaml

│   └── secret-reader-rolebinding.yaml

│

└── README.md

```



> Note: Secret manifests containing real credentials should never be committed to source control. The credentials used in this lab are intentionally non-production test values.



\---



\# 📌 Git Checkpoints



The project is developed incrementally with Git commits documenting major security milestones.



| Commit    | Milestone                                     |

| --------- | --------------------------------------------- |

| `9423f5f` | Add NAT gateway for private EKS networking    |

| `cf997a2` | Add EKS managed node group                    |

| `d050c4e` | Deploy Nginx application and internal service |

| `2821356` | Expose Nginx using AWS LoadBalancer           |

| `865c366` | Add Kubernetes NetworkPolicy isolation lab    |

| `6d27055` | Implement EKS Pod Identity least privilege    |

| `9a5072d` | Implement Kubernetes RBAC least privilege     |



\---



\# 🚧 Planned Security Enhancements



The lab will continue to evolve with additional security controls and attack scenarios.



Planned areas include:



\* EKS API endpoint hardening

\* Kubernetes Secrets hardening

\* EKS audit logging and security monitoring

\* Security Group analysis

\* Workload compromise simulation

\* Kubernetes privilege escalation scenarios

\* Lateral movement testing

\* Additional IAM hardening

\* Final security architecture review

\* Security control matrix and assessment



\---



\# 🎓 Key Security Principles Demonstrated



This lab focuses on practical application of:



\### Least Privilege



Give identities and workloads only the permissions they require.



\### Defence in Depth



Use multiple independent controls so that failure of one control does not result in complete compromise.



\### Zero Trust



Do not automatically trust workloads based on their location within the cluster.



\### Blast Radius Reduction



Limit what an attacker can access after compromising a workload.



\### Continuous Validation



Security controls should be tested rather than assumed to work.



\---



\# 🧰 Technologies



\* AWS

\* Amazon EKS

\* Kubernetes

\* Terraform

\* AWS IAM

\* Amazon S3

\* AWS VPC

\* AWS NAT Gateway

\* AWS Load Balancer

\* Kubernetes NetworkPolicy

\* Kubernetes RBAC

\* Kubernetes Secrets

\* PowerShell

\* kubectl

\* AWS CLI

\* Git / GitHub



\---



\## 🎯 Project Goal



The ultimate goal of this project is to demonstrate how a production-style EKS environment can be protected using \*\*layered security controls\*\*, while providing reproducible infrastructure and evidence-based security testing.



This is a hands-on security engineering lab rather than a purely theoretical Kubernetes exercise.



