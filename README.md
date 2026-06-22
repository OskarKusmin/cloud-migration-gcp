# Cloud Migration to GCP
Production-grade Kubernetes infrastructure with GitOps, monitoring, and CI/CD

## Project overview
This project is a cloud migration of a full-stack web application (React frontend, Go backend, and PostgreSQL database) to Google Cloud Platform. It is deployed to Kubernetes in two environments (test and production).

Infrastructure is provisioned with Terraform, deployed through Helm charts managed by ArgoCD (GitOps), and delivered through a GitLab CI pipeline that automatically deploys to test and requires manual approval for production. Monitoring and logging are handled by Prometheus, Grafana, Loki, and Alloy.\
Secrets are synced from GCP Secret Manager via External Secrets and DNS records are managed automatically by External DNS.

Three GCP projects isolate resources. `shared` (Artifact Registry, Terraform state), `test` and `prod`.
![architecture diagram](/Voyager.drawio.svg)

## Tech stack
Terraform, GKE, ArgoCD, Prometheus, Helm, etc.

## Infrastructure Design/Architecture

