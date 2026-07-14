# Cloud Migration to GCP
Production-grade Kubernetes infrastructure with GitOps, monitoring, and CI/CD

## Project Overview
This project is a cloud migration of a full-stack web application to Google Cloud Platform. The application runs on GKE in two environments (test and production), each in its own GCP project.

Infrastructure is provisioned with Terraform and deployed through Helm charts managed by ArgoCD following GitOps principles. A GitLab CI pipeline automatically deploys to `test` with manual approval required for `production`.

### Tech Stack
| Technology | Role |
|---|---|
| **Google Cloud Platform** | Cloud provider (GKE, Cloud SQL, Cloud DNS, Secret Manager, Artifact Registry) |
| **Terraform** | Infrastructure as Code to provision GCP resources |
| **Kubernetes (GKE)** | Container orchestration for clusters with dedicated node pools |
| **ArgoCD** | For continuous delivery using the app-of-apps pattern (GitOps) |
| **GitLab CI** | CI/CD pipeline that tests, builds, deploys with manual `prod` approval |
| **Helm** | Kubernetes package management with charts for all applications |
| **Prometheus & Grafana** | Monitoring cluster metrics, dashboards, alerting |
| **Loki & Alloy** | Log aggregation with centralized application and cluster logs |
| **External Secrets** | Secrets management that syncs secrets from GCP Secret Manager via Workload Identity |
| **External DNS** | DNS automation that creates DNS records from Kubernetes Ingress resources |
| **WireGuard** | VPN for secure access to private clusters |
| **Docker** | Container builds for frontend and backend |

**Application stack:** React (frontend), Go (backend), PostgreSQL (database)

## Architecture
### Infrastructure Design

### CI/CD Pipeline

### Cost Optimization

## Architecture Decisions

## Setup & Usage Guide

## Future Improvements
