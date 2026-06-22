#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# 1. Connecting to both clusters
echo "Configuring kubectl contexts..."
gcloud container clusters get-credentials "$TEST_CLUSTER" --zone "$TEST_ZONE" --project "$TEST_PROJECT"
gcloud container clusters get-credentials "$PROD_CLUSTER" --region "$PROD_REGION" --project "$PROD_PROJECT"

# 2. Deleting load-balancer-creating resources
echo "Releasing load balancers..."
kubectl --context "$TEST_CTX" delete ingress --all -n sample-app --ignore-not-found
kubectl --context "$PROD_CTX" delete ingress --all -n sample-app --ignore-not-found

echo "Patching ArgoCD service to ClusterIP..."
kubectl --context "$TEST_CTX" patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}' || true
echo "Waiting 30s for GCP to release forwarding rules..."
sleep 30

scale_down() {
  local PROJECT=$1 CLUSTER=$2 LOCATION_FLAG=$3

  for POOL in main tools monitoring; do
    echo "  [$CLUSTER] Disabling autoscaling on $POOL..."
    gcloud container clusters update "$CLUSTER" $LOCATION_FLAG --project "$PROJECT" --node-pool "$POOL" --no-enable-autoscaling

    echo "  [$CLUSTER] Scaling $POOL to 0..."
    echo "y" | gcloud container clusters resize "$CLUSTER" $LOCATION_FLAG --project "$PROJECT" --node-pool "$POOL" --num-nodes 0
  done
}

echo "Scaling down test node pools..."
scale_down "$TEST_PROJECT" "$TEST_CLUSTER" "--zone $TEST_ZONE"

echo "Scaling down prod node pools..."
scale_down "$PROD_PROJECT" "$PROD_CLUSTER" "--region $PROD_REGION"


verify_and_force_scale_down() {
  local PROJECT=$1 CLUSTER=$2

  echo "Verifying all nodes are scaled to 0..."
  local RETRIES=0
  while [ $RETRIES -lt 5 ]; do
    local ALL_ZERO=true
    
    gcloud compute instance-groups managed list --project="$PROJECT" \
      --filter="name~gke-$CLUSTER" \
      --format="csv[no-heading](name,zone,targetSize)" | while IFS=, read -r NAME ZONE_URL SIZE; do
      if [ "$SIZE" != "0" ]; then
        ZONE=$(basename "$ZONE_URL")
        echo "  $NAME still at targetSize=$SIZE, force-resizing..."
        gcloud compute instance-groups managed resize "$NAME" \
          --size=0 --zone="$ZONE" --project="$PROJECT" --quiet
        ALL_ZERO=false
      fi
    done

    if $ALL_ZERO; then
      echo "  All instance groups at 0."
      return 0
    fi

    RETRIES=$((RETRIES + 1))
    echo "  Waiting 30s before re-checking (attempt $RETRIES/5)..."
    sleep 30
  done
}

verify_and_force_scale_down "$TEST_PROJECT" "$TEST_CLUSTER"
verify_and_force_scale_down "$PROD_PROJECT" "$PROD_CLUSTER" 

echo "Stopping Cloud SQL instances..."
gcloud sql instances patch $TEST_DB --activation-policy=NEVER --project "$TEST_PROJECT"
gcloud sql instances patch $PROD_DB --activation-policy=NEVER --project "$PROD_PROJECT"

echo "✅ All expensive resources stopped."