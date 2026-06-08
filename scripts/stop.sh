#!/bin/bash
set -euo pipefail

# 1. Connecting to both clusters
echo "Configuring kubectl contexts..."
gcloud container clusters get-credentials "voyager-test" --zone "europe-north1-b" --project ""
gcloud container clusters get-credentials "voyager-prod" --region "europe-north1" --project ""

# 2. Deleting load-balancer-creating resources
echo "Releasing load balancers..."
kubectl --context "gke__europe-north1-b_voyager-test" delete ingress --all -n sample-app --ignore-not-found
kubectl --context "gke__europe-north1_voyager-prod" delete ingress --all -n sample-app --ignore-not-found

echo "Patching ArgoCD service to ClusterIP..."
kubectl --context "gke__europe-north1-b_voyager-test" patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}' || true
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
scale_down "" "voyager-test" "--zone europe-north1-b"

echo "Scaling down prod node pools..."
scale_down "" "voyager-prod" "--region europe-north1"


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

verify_and_force_scale_down "" "voyager-test"
verify_and_force_scale_down "" "voyager-prod"

echo "Stopping Cloud SQL instances..."
gcloud sql instances patch voyager-test-db --activation-policy=NEVER --project ""
gcloud sql instances patch voyager-prod-db --activation-policy=NEVER --project ""

echo "✅ All expensive resources stopped."