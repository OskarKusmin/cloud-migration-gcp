# cloud-migration-gcp

### Table of Contents
- [Project overview](#project-overview)
- [Setup and installation](#setup-and-installation)
  - [Prerequisites](#prerequisites)
  - [1. Initial groundwork](#1-initial-groundwork)
  - [2. Replacing hardcoded values](#2-replacing-hardcoded-values)
  - [3. Terraform configuration](#3-terraform-configuration)
  - [4. Test environment](#4-test-environment)
  - [5. Production environment](#5-production-environment)
  - [6. ArgoCD configuration](#6-argocd-configuration)
  - [7. GitLab CI](#7-gitlab-ci)
  - [8. DNS](#8-dns)
- [Usage guide](#usage-guide)
  - [Accessing the application](#accessing-the-application)
  - [Accessing ArgoCD](#accessing-argocd)
  - [Deploying changes](#deploying-changes)
  - [Accessing monitoring dashboards](#accessing-monitoring-dashboards)
  - [Infrastructure management](#infrastructure-management)
- [Review questions](#review-questions)

## Project overview
This project is a cloud migration of a full-stack web application (React frontend, Go backend, and PostgreSQL database) to Google Cloud Platform. It is deployed to Kubernetes in two environments (test and production).

Infrastructure is provisioned with Terraform, deployed through Helm charts managed by ArgoCD (GitOps), and delivered through a GitLab CI pipeline that automatically deploys to test and requires manual approval for production. Monitoring and logging are handled by Prometheus, Grafana, Loki, and Alloy.\
Secrets are synced from GCP Secret Manager via External Secrets and DNS records are managed automatically by External DNS.

Three GCP projects isolate resources. `shared` (Artifact Registry, Terraform state), `test` and `prod`.
![architecture diagram](/Voyager.drawio.svg)
GitLab repository is available [here.](https://gitlab.com/kood-voyager-group/kood-voyager-project)\
Production application: https://www.kood-voyager.com/

## Setup and installation
#### Prerequisites
- Clone the repository (https://gitea.kood.tech/oskarkusmin/voyager.git)
- [GCP account](https://cloud.google.com)
- Domain name with registrar access
- [GitLab account](https://about.gitlab.com)
- Terraform, Helm, kubectl, gcloud CLI, argocd CLI installed
- Docker installed (for local builds)
- WireGuard installed (for VPN access to private clusters)

### 1. Initial groundwork
#### IAM
1. Create three GCP projects: `voyager-shared`, `voyager-test`, `voyager-prod`
2. Create a `terraform` service account in the `voyager-shared` project:
   - Grant it **Owner** on `voyager-shared`
   - Grant it **Editor** on `voyager-test` and `voyager-prod`
   - Create and download a JSON key (keep out of repo `.gitignore`)

#### Domain
- Register a domain at a registrar of your choice
- DNS zones and records are managed by Terraform and External DNS. No manual DNS configuration needed. Only NS delegation (done in [step 8](#8-dns))

#### Terraform state
- Create a GCS bucket in `voyager-shared` for remote state and name it `voyager-tf-state`
- Enable object versioning on the bucket

#### Extra (Optional but recommended):
- Enable **2-Step Verification** on your Google account
- Create a budget in Billing -> Budgets & alerts
  - Set alert thresholds at **25%, 50%, 75%, 100%** of your budget and enable email notifications

### 2. Replacing hardcoded values
There are hardcoded values you will need replace in these directories to match your setup. 
- `/cluster-config`
- `/terraform`
- `/sample-app`
- `/scripts`
- `/argocd`

Here are the values to replace when found
- `kood-voyager.com` -> your domain
- `voyager-test-489716` -> your test project ID
- `voyager-prod-489709` -> your prod project ID 
- `voyager-shared-489709` -> your shared project ID
- `https://gitlab.com/kood-voyager-group/kood-voyager-project.git` -> your GitLab repo URL
- `https://discord.com/api/webhooks/123456789/qwerty/slack` -> Your webhook URL

### 3. Terraform configuration
Create these Terraform variable files.
**`terraform/shared/terraform.tfvars`**
```sh
project_id = "voyager-shared-XXXXX"
region     = "europe-north1"
```

**`terraform/test/terraform.tfvars`**
```sh
project_id        = "voyager-test-XXXXX"
region            = "europe-north1"
shared_project_id = "voyager-shared-XXXXX"
prod_project_id   = "voyager-prod-XXXXX"
domain            = "yourdomain.com"
```

**`terraform/prod/terraform.tfvars`** (same thing, just for prod):
```sh
project_id        = "voyager-prod-XXXXX"
region            = "europe-north1"
shared_project_id = "voyager-shared-XXXXX"
test_project_id   = "voyager-test-XXXXX"
zones             = ["europe-north1-b", "europe-north1-c"]
domain            = "yourdomain.com"
```

Then apply
```sh
cd terraform/shared
terraform init && terraform apply
```

### 4. Test environment
Provision test environment infrastructure (networking, GKE, database, DNS, secrets, VPN, ArgoCD, etc.)
```sh
cd terraform/test
terraform init && terraform apply
```

Connect kubectl to the new cluster:
```sh
gcloud container clusters get-credentials voyager-test \
  --zone europe-north1-b --project voyager-test-XXXXX
```

Verify the cluster is reachable:
```sh
kubectl get nodes
```

### 5. Production environment
Same as test but with HA: regional GKE cluster, multi-zone Cloud SQL.\
ArgoCD is not installed here. It runs on the test cluster and manages both.
```sh
cd terraform/prod
terraform init && terraform apply
```
Connect kubectl to the prod cluster:
```sh
gcloud container clusters get-credentials voyager-prod \
  --region europe-north1 --project voyager-prod-XXXXX
```
Verify:
```sh
kubectl get nodes
```

### 6. ArgoCD configuration
Switch kubectl to the test cluster (ArgoCD runs here):
```sh
kubectl config use-context gke_voyager-test-XXXXX_europe-north1-b_voyager-test
```

Get the initial admin password:
```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Get the ArgoCD server IP:
```sh
kubectl -n argocd get svc argocd-server \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Log in:
```sh
argocd login <ARGOCD-IP> --plaintext \
  --username admin --password <password>
```

Add the GitLab repository:
```sh
argocd repo add https://gitlab.com/your-project.git \
  --username <gitlab-user> --password <gitlab-access-token>
```

Register the prod cluster:
```sh
argocd cluster add gke_voyager-prod-XXXXX_europe-north1_voyager-prod
```

Create the parent apps:
```sh
argocd app create test-apps \
  --repo https://gitlab.com/your-project.git \
  --path argocd/test/applications \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd

argocd app create prod-apps \
  --repo https://gitlab.com/your-project.git \
  --path argocd/prod/applications \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd
```

Generate a token for GitLab CI (used in next step):
```sh
argocd account generate-token --account gitlab-ci
```

### 7. GitLab CI
Update the variables in `.gitlab-ci.yml` to match your setup:
- `REGISTRY` — your Artifact Registry URL
- `ARGOCD_SERVER` — your ArgoCD hostname (e.g., `argocd.test-public.yourdomain.com`)

In GitLab, go to **Settings -> CI/CD -> Variables** and add:
| Variable            | Value                                    | Options           |
|---------------------|------------------------------------------|-------------------|
| `GCP_SA_KEY`        | Contents of the service account JSON key | Masked, Protected |
| `ARGOCD_AUTH_TOKEN` | Token from previous step                 | Masked, Protected |

Push to `main` to trigger the pipeline.

### 8. DNS
Terraform created Cloud DNS zones for each environment. You need to delegate these subdomains at your domain registrar.

Find the nameservers for each zone:
```sh
gcloud dns managed-zones describe test-public \
  --project voyager-test-XXXXX \
  --format="value(nameServers)"

gcloud dns managed-zones describe prod-public \
  --project voyager-prod-XXXXX \
  --format="value(nameServers)"
```

At your domain registrar, create **NS records** for each subdomain:
| Record                       | Type  | Value                              |
|------------------------------|-------|------------------------------------|
| `test-public.yourdomain.com` | NS    | *(nameservers from command above)* |
| `prod-public.yourdomain.com` | NS    | *(nameservers from command above)* |
| `www.yourdomain.com`         | CNAME | `prod-public.yourdomain.com`       |

Once delegation propagates, External DNS (running in each cluster) will automatically create A records for your Ingresses within these zones.

## Usage guide
### Accessing the application
The application is a user registration and login page.
- Frontend:
  - `https://frontend.test-public.yourdomain.com`
  - `https://www.yourdomain.com`
- Backend API:
  - `https://backend.test-public.yourdomain.com`
  - `https://backend.prod-public.yourdomain.com`

DNS records are created automatically by External DNS.\
TLS certificates are provisioned by GKE managed certificates.

---
### Accessing ArgoCD
ArgoCD runs on the test cluster and manages both environments.

UI: `http://argocd.test-public.yourdomain.com`

Command to get initial admin password:
```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

The dashboard shows apps for both environments. Each app displays its sync status (if Git matches the cluster) and health status (if pods are running correctly).

---
### Deploying changes
Pushing to `main` triggers the GitLab CI pipeline:
1. Test: Runs backend integration tests through Docker Compose.
2. Build: Builds Docker images for frontend and backend, tagged with the commit SHA, and pushes them to Artifact Registry.
3. Deploy to test (automatic): Updates the image tag in ArgoCD and waits for the apps to become healthy.
4. Deploy to prod (manual): A manual action in the GitLab pipeline UI. Click to approve.

---
### Accessing monitoring dashboards
Grafana uses an internal load balancer and is only accessible from within the VPC. Connect to the WireGuard VPN first.

1. Generate client keys:
```sh
wg genkey | tee client_private.key | wg pubkey > client_public.key
```

2. SSH into the VPN server and get the server's public key:
```sh
gcloud compute ssh wireguard-vpn --zone europe-north1-b \
  --project voyager-test-XXXXX --tunnel-through-iap

sudo cat /etc/wireguard/server_public.key
```

3. When SSH'd in, add your client as a peer:
```sh
sudo wg set wg0 peer $(cat <<< '<client-public-key>') allowed-ips 10.100.0.2/32
```

4. Create a local WireGuard config file (`wg0.conf`):
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.100.0.2/24

[Peer]
PublicKey = <server-public-key>
Endpoint = <vpn-static-ip>:51820
AllowedIPs = 10.0.0.0/20, 10.100.0.0/24
PersistentKeepalive = 25
```

5. Connect:
```sh
wg-quick up ./wg0.conf
```

6. Port forward Grafana and access it through `http://localhost:3000`
```sh
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Username: admin
# Password: prom-operator
```

### Infrastructure management
I created two scripts that were used during development to save on costs when not working on the project. 

#### Stop (cost saving)
```sh
./scripts/stop.sh
```
Releases load balancers, scales all node pools to 0 in both clusters, and stops Cloud SQL instances. Only storage costs remain (persistent disks, Cloud SQL storage, static IPs).

#### Start
```sh
./scripts/start.sh
```
Restarts Cloud SQL, scales node pools back up with autoscaling, restores ArgoCD, configures kubectl, and verifies both environments. It takes around 5-10 minutes after the script completes to regain full access.

## Review questions

>***Student can explain reasoning behind choosing the specific cloud provider***

I decided on GCP back in the Cloud Cartographer project for these reasons:
- GCP offers €254 free usage credits to new accounts which is sufficient for me to work through the project from start to finish, with room for mistakes and experimentation, without having to pay for any services myself. 
- Google Kubernetes Engine (GKE) is a more suitable managed Kubernetes services among the major providers since Google originally created Kubernetes. Other providers seem to require more manual configuration.

---

> ***Student can explain the cost optimization strategies used for cloud resources***

- Instance size optimization\
For this project, it made sense to use the the fewest resources I could get away with while still satisfying the mandatory testing requirements.
  - All GKE node pools use `e2-medium` (2 vCPU, 4GB RAM) which is the smallest practical size for running Kubernetes workloads. (`terraform/test/variables.tf`).\
  - Cloud SQL uses `db-f1-micro` which the smallest available tier (`terraform/test/variables.tf`).\
  - GKE managed Prometheus is disabled (`monitoring_enable_managed_prometheus = false`) since we run our own Prometheus, avoiding duplicate costs.


- Billing alert implementation\
Budget alerts configured in GCP Billing at 25%, 50%, 75%, and 95% thresholds with email notifications. (Set up manually in the GCP Console).

- Lifecycle policy configuration for buckets and container registries
  - Artifact Registry has cleanup policies to prevent image accumulation from CI/CD. The 20 most recent tagged images are kept and untagged images older than 7 days are automatically deleted. (`terraform/shared/artifact-registry.tf`)
  - The Terraform state bucket (`voyager-tf-state`) has object versioning enabled with lifecycle rules. Noncurrent versions are deleted after 30 days or when more than 5 newer versions exist. This keeps enough history for state recovery while preventing storage growth. (Manually configured in GCP console)

- Resource-efficient test environment configuration (e.g., smaller instances, no HA)
  - Test GKE cluster is zonal (single control plane, single zone) vs prod which is regional (HA). (`terraform/test/gke.tf` `regional = false` vs `terraform/prod/gke.tf` `regional = true`)
  - Test database is zonal (no standby replica) vs prod which is regional (automatic failover). (`terraform/test/database.tf` `availability_type = "ZONAL"` vs `terraform/prod/database.tf` `availability_type = "REGIONAL"`)
  - Test backup retention is 7 daily backups with 1 day of transaction logs vs prod's 30 daily backups with 7 days of logs.

- Resource cleanup strategies and automation\
`scripts/stop.sh` scales all node pools to 0 and stops Cloud SQL instances, removing compute and database costs. This preserves cluster state while reducing idle costs. Only storage costs for persistent disks and Cloud SQL storage remain. `scripts/start.sh` restores everything.\
Infrastructure can also be fully destroyed and recreated via `terraform destroy` / `terraform apply`.

---

>***Student can explain what is least privilege principle and why it is important***

The principle of least privilege is the concept that a user, service account or application should only have access to what they need to perform their responsibilities, and no more. The more a user has access to, the greater the negative effect if their account is compromised.\
If appropriately applied, it limits the possible blast radius of an incident cause by compromised credentials. An attacker can only do what that account is allowed to. A Grafana service account with `monitoring.viewer` can read metrics but can't delete the database. 

This is how it is applied in this project:
- Separate GCP projects per environment so test resources can't affect prod and vice versa.
- Each tool gets its own scoped service account with only the roles it needs:
  - `external-secrets` has `secretmanager.secretAccessor` (can read secrets, not create or delete them)
  - `external-dns` has `dns.admin` (can manage DNS records, nothing else)
  - `grafana` has `monitoring.viewer` (read-only access to cloud metrics).
- ArgoCD RBAC rules are set so the `gitlab-ci` account can only sync and get applications, not modify ArgoCD settings or delete projects.

---

>***Separate user for administrative tasks exists***

The root user (personal Google account) is only used for initial project setup. All infrastructure management is performed through a dedicated terraform service account created in the `shared` project (`terraform@voyager-shared-489709.iam.gserviceaccount.com`) . CI/CD authenticates using this service account's key stored as a GitLab CI variable.

---

>***Student can explain why separate user is needed for administrative tasks and why root user must not be used***

The root account (personal Google account) is the most powerful user. It owns the billing account, can create and delete entire projects, and cannot have its permissions revoked. If it's compromised, everything could be lost.\
By using a separate admin service account for everyday tasks credentials are isolated.\
Service account keys can be rotated or revoked without affecting the root account. If the Terraform service account key leaks, we can revoke it and generate a new one. The root account remains safe.\
Even if the service account has broad permissions, it is still scoped to specific projects and can be audited.\
This also gives us a clearer audit trail. When infrastrucure changes are made by `terraform@voyager-shared.iam.gserviceaccount.com`, it's obvious in the audit logs.

---

>***MFA is enabled for all users***

MFA is enabled on my personal Google account (root user). Service accounts authenticate via keys and Workload Identity, which don't use passwords so they don't support MFA.

---

>***Student can explain benefits and drawbacks of using separate accounts/projects for testing and production environments and shared resources***

Benefits:
- Misconfigured Terraform apply or script in test can't accidentally destroy production resources. The blast radius of an incident is isolated to its own project. 
- Each environment has independent IAM. We can grant developers broad access to the test project (for debugging and experimentation) without giving access to production.
- Separate billing visibility. We can see exactly how much each environment costs. If test spending spikes unexpectedly, it's visible without having to dig through shared billing data to figure out where the cost originates.

Drawbacks:
- There is more infrastructure to manage. Three projects each need their own API enablement, IAM policies, and Terraform code. This increases operational complexity.
- Access across projects is more complex. Nodes in `voyager-test` need to pull images from `voyager-shared`. This requires explicit IAM bindings across projects (Artifact Registry Reader role). With a single project, everything can access everything by default.
- Cost is higher because some resources are duplicated per environment (NAT gateways, Cloud SQL instances, load balancers). A single project with namespace isolation in Kubernetes would be cheaper, but less isolated.

---

>***Student can explain why NAT gateway is needed and how it works***

The GKE nodes are private and have no public IP addresses. But the nodes still need internet access to pull container images, download packages, and communicate with external APIs.\
A NAT (Network Address Translation) gateway solves this. Without NAT, private nodes would have no way to reach the internet, and pods couldn't pull images.

It works like this:
1. A private node (`10.0.x.x`) sends a request to the internet (like pulling an image from Docker Hub)
2. The NAT takes the request and replaces the source IP with its own public IP
3. The external server responds to the NAT's public IP
4. The NAT translates the response back to the private node's IP and forwards it

Traffic only goes out. The internet can't connect to private nodes through NAT. Inward traffic goes through load balancers instead.

---

>***Student can explain the difference between internal and external load balancers and when should they be used***

External load balancer has a public IP address and accepts traffic from the internet. Used for services that end users need to reach like the frontend and ArgoCD (for CI/CD access).

Internal load balancer has a private IP address only reachable from within the VPC (or through a VPN). Used for services that should not be exposed to the internet but need to be accessible internally. In this project, Grafana uses an internal load balancer.

---

>***Student can explain High Availability (HA), it's benefits and drawbacks***

High Availability means designing a system with redundancies so that it continues to work when individual components fail. Usually by running multiple replicas of critical components across seperate availability zones.

Benefits:
- HA makes application more resilient to infrastructure failures. If an AZ goes down, the application continues serving users from another AZ. 
- Enables database failover. If the primary Cloud SQL instance fails, the standby automatically promotes in seconds rather than requiring to restore from backup.
- We can perform rolling updates and node upgrades without interrupting access for users.

Drawbacks:
- HA doubles the resource cost. A regional Cloud SQL instance runs a standby replica we pay for but don't activel use. A regional GKE cluster runs nodes in multiple zones.
- Increased complexity because there are more components to manage and more potential for configuration errors.
- Communication between pods in different zones adds a small amount of network latency (usually negligible but relevant for latency-sensitive processes).

In this project the prod environment uses HA:
- Regional control plane `regional = true` gives 2 control plane replicas across zones.
- Prod GKE node pools are across 2 zones (`europe-north1-b`, `europe-north1-c`)
- Cloud SQL is set to `availability_type = "REGIONAL"` which enables automatic failover to a standby replica in another zone. 

---

>***Student can explain the benefits and drawbacks of not using public IP addresses for control plane and nodes***

Benefits:
- Reduced attack surface because with no public IPs, the control plane and nodes are not reachable from the internet.
- No risk of accidental exposure. A misconfigured RBAC policy or an overly permissive Service won't accidentally expose internal resources to the public internet.
- Compliance with security regulations that might require infrastructure components to not be accessible from the internet. Private nodes and control plane satisfy this by default.

Drawbacks:
- Access is more complex because we can't just run `kubectl` from a laptop directly. We need an access path into the VPC. In this project we use a WireGuard VPN (`vpn.tf`).
- CI/CD also becomes more complicated because GitLab CI runners on the internet can't reach the private control plane directly. ArgoCD solves this because it runs inside the cluster and pulls from Git. But the ArgoCD server itself still needed to be exposed for CLI access from CI.
- Private nodes can't reach the internet without a Cloud NAT gateway, which is an additional resource and cost.

---

>***Student can explain the benefits and drawbacks of using private and public DNS zones***

Public DNS zones resolve from anywhere on the internet. They map domain names to public IP addresses so that external users can reach our services.\
Private DNS zones resolve only from within the VPC. They map domain names to private IP addresses for internal service discovery. 

Benefits:
- Private DNS provides security through separation. Internal resources (databases, internal APIs) are not visible in public DNS. An attacker can't discover our database hostname or internal service topology through DNS lookups.
- Internal endpoints like `db.test-private.kood-voyager.com` always resolves to the database, even if the IP changes. Applications don't need to be reconfigured. Just the DNS record updates.
- Configuration is simpler because applications reference human-readable hostnames instead of IP addresses. The backend connects to `db.test-private.kood-voyager.com` rather than a hardcoded IP that could change.

Drawbacks:
- Managing two sets of zones to manage per environment is more complicated because of different visibility rules. Debugging DNS issues requires knowing which zone a record is in and where it's resolvable from.
- If the same domain name existed in both a public and private zone with different records, requests would resolve differently depending on where they originate. This can cause confusing bugs. (Avoided in this project by using distinct subdomains: `test-public` vs `test-private`.)
- Private zones require VPC access. I can't resolve private DNS records from my laptop unless I connected to the VPC (e.g., through VPN). 
---

>***Student can explain what are TLS certificates and why they are used***

A TLS (Transport Layer Security) certificate is a data file hosted in a website's origin server. It enables encrypted and authenticated communication between client and server. The certificate may contain a website's public key and identity along with related information. This is what makes HTTPS work.\
Data sent between the client and server is encrypted so anyone intercepting the traffic (like on a public Wi-Fi network) can't read it.\
The certificate proves that the server is who it claims to be. When a browser connects to `kood-voyager.com`, the TLS certificate proves it's actually our server, not an impersonator. 

In this project:
- Public DNS zones use Google-managed certificates provisioned automatically by the GKE Ingress controller (no manual certificate management needed).
- Private DNS zones use wildcard certificates (e.g., `*.test-private.kood-voyager.com`) created via Google Certificate Manager in Terraform, securing internal traffic between services within the VPC.

---

>***Student can explain the difference between point in time recovery and daily backups***

Daily backups are snapshots of the database taken once per day (03:00 in this project). They capture the database state at that moment and it can be restored to that exact point in time if needed.\
This has a limitation. If the backup runs at 03:00 and the database fails at 22:00, 19 hours of data is lost.

Point in time recovery compensates for that limitation. Along with daily backups, the database constantly records transaction logs (a record of every write operation). To restore, we pick any timestamp within the retention period and the system replays the daily backup plus the transaction logs to that exact second. This means we can recover to the moment just before a failure with minimal data loss.

---

>***App of apps pattern is used in ArgoCD***
>*Ask student to show and briefly explain the app of apps pattern*

The app-of-apps pattern is a way to load multiple ArgoCD applications from a single parent application. Instead of creating applications one by one, we create a parent application that points to a Helm chart whose templates are ArgoCD application CRDs.

In this project, the parent app `test-apps` points to `argocd/test/applications/`, which is a Helm chart containing templates for each child application. When ArgoCD syncs the parent, it renders the templates and creates all the child applications automatically.

---

>***Student can explain why ArgoCD is used and how it works***

ArgoCD lets us implement GitOps which a practice where the desired state of the infrastructure is in Git, and an automated tool ensures the cluster matches that state.\
Without it, deployments need manual commands like `helm install` or `kubectl apply`. This is not auditable, and doesn't self-heal if someone makes a manual change to the cluster.

The way ArgoCD works is it runs inside the Kubernetes cluster and watches the Git repository. For each application, it compares the desired state (Git) with the live state (actually running in the cluster). If there is a difference, ArgoCD can automatically reconcile the difference.

---

>***Student can explain why External Secrets is used and how it works***

Kubernetes has Secret objects that need to be created and managed. But we shouldn't hardcode secrets in Helm values or Git because it is a security risk.

External Secrets lets us have a single source of truth for sensitive data in GCP Secret Manager, while making those secrets available to pods as standard Kubernetes Secrets.

How it works:
1. `ClusterSecretStore` tells External Secrets how to connect to GCP Secret Manager. It authenticates through Workload Identity (no credential files needed).
2. `ExternalSecret` defines which secrets to fetch. For example, the backend's ExternalSecret specifies "get `voyager-test-db-credentials` from GCP Secret Manager and extract the `password`, `username`, `database`, and `host` fields."
3. External Secrets Operator watches ExternalSecret resources, fetches the values from GCP Secret Manager, and creates a Kubernetes Secret containing the data.
4. The pod uses this Secret like any other — via `envFrom` or volume mounts. It doesn't matter to the pod that the secret came from GCP.
5. The operator periodically refreshes (every 1 hour in this project), so rotated secrets update automatically without redeploying.

---

>***Database credentials are stored in cloud provider secret management service and are being accessed using External Secrets***
>*Ask student to show and briefly explain how database credentials are accessed using External Secrets*

Database credentials are stored in GCP Secret Manager and accessed by pods through External Secrets Operator. 

1. Terraform generates credentials and stores them in GCP Secret Manager (`terraform/test/secrets.tf`). A random password is generated, a Cloud SQL user is created with it, and a JSON secret containing `username`, `password`, `database`, and `host` is written to Secret Manager (`voyager-test-db-credentials`).
2. ClusterSecretStore tells External Secrets how to connect to GCP Secret Manager (`cluster-config/test/clustersecretstore.yaml`). It authenticates with Workload Identity. No credential files, the Kubernetes service account is bound to a GCP service account with `secretmanager.secretAccessor` role (`terraform/test/iam.tf`).
3. ExternalSecret tells which secrets to fetch (`sample-app/backend/helm/templates/externalsecret.yaml`). It references the ClusterSecretStore and specifies the secret key (`voyager-test-db-credentials`) and what to extract (`password`, `username`, `database`, `host`). External Secrets Operator fetches these values and creates a standard Kubernetes Secret.
4. The backend pod uses the Kubernetes Secret (`sample-app/backend/helm/templates/deployment.yaml`). The Secret is injected as environment variables via `envFrom: secretRef`. The application reads `POSTGRES_PASSWORD`, `POSTGRES_USER`, etc. from its environment and connects to the database.

The credential values never appear in Git. Only the ExternalSecret definition (which references secret names, not values) is committed.

---

>***Student can explain why External DNS is used and what it does***

External DNS watches Kubernetes Ingress resources. When it sees a hostname on the resources (like `frontend.test-public.kood-voyager.com`) it creates or updates matching DNS records in Google Cloud DNS.\
So DNS stays in sync with what is deployed in the cluster and we don't have to manually edit DNS for every service.

External DNS is used because it adds automation and is aligned with GitOps. Desired hostnames are kept in Git with the rest of the app config. The cluster and External DNS apply them.
We define the hostname once in the Helm chart or Ingress and A record appears automatically.\
Using External DNS helps avoid mistakes because the record points at the current load balancer IP. If the LB is recreated, External DNS can update the record so traffic still reaches the right place. 

In this project Ingresses for frontend and backend specify hosts under `test-public` and `prod-public`. External DNS writes A records into the matching public Cloud DNS zones.

---