#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "Starting Cloud SQL instances..."
gcloud sql instances patch $TEST_DB --activation-policy=ALWAYS --project "$TEST_PROJECT" --async --quiet
gcloud sql instances patch $PROD_DB --activation-policy=ALWAYS --project "$PROD_PROJECT" --async --quiet

echo "Scaling up test tools pool (ArgoCD)..."
echo "y" | gcloud container clusters resize "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT" --node-pool tools --num-nodes 1

gcloud container clusters update "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT" --node-pool tools --enable-autoscaling --min-nodes 1 --max-nodes 2

echo "Scaling up remaining test pools..."
for POOL in main monitoring; do
  echo "y" | gcloud container clusters resize "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT" --node-pool "$POOL" --num-nodes 1

  if [ "$POOL" = "main" ]; then
    MAX=3
  else
    MAX=2
  fi

  gcloud container clusters update "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT" --node-pool "$POOL" --enable-autoscaling --min-nodes 1 --max-nodes "$MAX"
done

echo "Scaling up prod pools..."
for POOL in main tools monitoring; do
  echo "y" | gcloud container clusters resize "$PROD_CLUSTER" --region "$PROD_REGION" --project "$PROD_PROJECT" --node-pool "$POOL" --num-nodes 1

  if [ "$POOL" = "main" ]; then
    MAX=2
  else
    MAX=1
  fi

  gcloud container clusters update "voyager-prod" --region "$PROD_REGION" --project "$PROD_PROJECT" --node-pool "$POOL" --enable-autoscaling --min-nodes 1 --max-nodes "$MAX"
done

echo "Configuring kubectl..."
gcloud container clusters get-credentials "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT"
gcloud container clusters get-credentials "$PROD_CLUSTER" --region "$PROD_REGION" --project "$PROD_PROJECT"
kubectl config use-context "$TEST_CTX"

echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "Restoring ArgoCD service to LoadBalancer..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}' || true

echo "Waiting for Cloud SQL instances..."
for DB_INSTANCE in "$TEST_DB:$TEST_PROJECT" "$PROD_DB:$PROD_PROJECT"; do
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
kubectl --context "$TEST_CTX" get nodes
kubectl --context "$TEST_CTX" get pods -n sample-app

echo ""
echo "=== Prod environment ==="
kubectl --context "$PROD_CTX" get nodes
kubectl --context "$PROD_CTX" get pods -n sample-app

echo ""
echo "ArgoCD app status:"
ARGOCD_IP=$(kubectl --context "$TEST_CTX" get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo "ArgoCD UI: http://$ARGOCD_IP (may take a few minutes for LB IP)"
echo ""
echo "All resources started. Apps will be fully accessible in ~5-10 minutes after GCP load balancer health checks pass."