#!/bin/bash
set -euo pipefail

echo "Starting Cloud SQL instances..."
gcloud sql instances patch voyager-test-db --activation-policy=ALWAYS --project "" --async --quiet
gcloud sql instances patch voyager-prod-db --activation-policy=ALWAYS --project "" --async --quiet

echo "Scaling up test tools pool (ArgoCD)..."
echo "y" | gcloud container clusters resize "voyager-test" --zone "europe-north1-b" --project "" --node-pool tools --num-nodes 1

gcloud container clusters update "voyager-test" --zone "europe-north1-b" --project "" --node-pool tools --enable-autoscaling --min-nodes 1 --max-nodes 2

echo "Scaling up remaining test pools..."
for POOL in main monitoring; do
  echo "y" | gcloud container clusters resize "voyager-test" --zone "europe-north1-b" --project "" --node-pool "$POOL" --num-nodes 1

  if [ "$POOL" = "main" ]; then
    MAX=3
  else
    MAX=2
  fi

  gcloud container clusters update "voyager-test" --zone "europe-north1-b" --project "" --node-pool "$POOL" --enable-autoscaling --min-nodes 1 --max-nodes "$MAX"
done

echo "Scaling up prod pools..."
for POOL in main tools monitoring; do
  echo "y" | gcloud container clusters resize "voyager-prod" --region "europe-north1" --project "" --node-pool "$POOL" --num-nodes 1

  if [ "$POOL" = "main" ]; then
    MAX=2
  else
    MAX=1
  fi

  gcloud container clusters update "voyager-prod" --region "europe-north1" --project "" --node-pool "$POOL" --enable-autoscaling --min-nodes 1 --max-nodes "$MAX"
done

echo "Configuring kubectl..."
gcloud container clusters get-credentials "voyager-test" --zone "europe-north1-b" --project ""
gcloud container clusters get-credentials "voyager-prod" --region "europe-north1" --project ""
kubectl config use-context "gke__europe-north1-b_voyager-test"

echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "Restoring ArgoCD service to LoadBalancer..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}' || true

echo "Waiting for Cloud SQL instances..."
for DB_INSTANCE in voyager-test-db: voyager-prod-db:; do
  INSTANCE="${DB_INSTANCE%%:*}"
  PROJECT="${DB_INSTANCE##*:}"
  while true; do
    STATE=$(gcloud sql instances describe "$INSTANCE" \
      --project "$PROJECT" --format="value(state)" 2>/dev/null || echo "UNKNOWN")
    if [ "$STATE" = "RUNNABLE" ]; then
      echo "  $INSTANCE is running."
      break
    fi
    echo "  $INSTANCE state: $STATE, waiting 10s..."
    sleep 10
  done
done

echo ""
echo "⏳ Waiting for pods to stabilize..."
sleep 30

echo ""
echo "=== Test environment ==="

echo ""
echo "=== Prod environment ==="
kubectl --context "gke__europe-north1_voyager-prod" get nodes
kubectl --context "gke__europe-north1_voyager-prod" get pods -n sample-app

echo ""
echo "ArgoCD app status:"
ARGOCD_IP=$(kubectl --context "")
echo "ArgoCD UI: http://$ARGOCD_IP (may take a few minutes for LB IP)"
echo ""
echo "All resources started. Apps will be fully accessible in ~5-10 minutes after GCP load balancer health checks pass."