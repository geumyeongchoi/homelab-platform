#!/usr/bin/env bash
# 모든 변경은 저장소 파일 → 이 스크립트. 사용: DOMAIN=example.com ACME_EMAIL=me@x.com GRAFANA_ADMIN_PASSWORD=... scripts/apply.sh [platform|observability|apps|all]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DOMAIN:?}" "${ACME_EMAIL:?}"
TARGET="${1:-all}"
platform() {
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s
  envsubst < k3s/30-cluster-issuer.yaml | kubectl apply -f -
  kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
}
observability() {
  kubectl create ns observability --dry-run=client -o yaml | kubectl apply -f -
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
  helm repo update >/dev/null
  envsubst < helm/values/kube-prometheus-stack.yaml | helm upgrade --install kps prometheus-community/kube-prometheus-stack -n observability -f -
  helm upgrade --install loki grafana/loki -n observability -f helm/values/loki.yaml
  helm upgrade --install tempo grafana/tempo -n observability -f helm/values/tempo.yaml
  helm upgrade --install otel-collector open-telemetry/opentelemetry-collector -n observability -f helm/values/otel-collector.yaml
  kubectl -n observability create configmap dashboards --from-file=docs/dashboards/ --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
}
apps() {
  for app in docmind flashgate; do
    kubectl create ns $app --dry-run=client -o yaml | kubectl apply -f -
    helm upgrade --install $app helm/$app -n $app --set ingress.host=$( [ $app = flashgate ] && echo flash || echo $app ).$DOMAIN
  done
}
case "$TARGET" in
  platform) platform ;; observability) observability ;; apps) apps ;;
  all) platform; observability; apps ;;
esac
kubectl get pods -A | grep -vE "Running|Completed" || echo "✓ all pods Running/Completed"
