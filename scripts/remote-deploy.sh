#!/usr/bin/env bash
# GitHub Actions → SSH(deploy 사용자, forced command) → 이 스크립트. 인자는 SSH_ORIGINAL_COMMAND = "<app> <image>".
# 허용 앱·이미지 prefix 만 배포. 롤아웃 실패 시 자동 undo. 다른 명령은 실행 불가(키가 이 스크립트에 고정).
set -euo pipefail
read -r APP IMAGE <<<"${SSH_ORIGINAL_COMMAND:-}"
case "$APP" in docmind|flashgate) ;; *) echo "denied app: $APP" >&2; exit 2 ;; esac
[[ "$IMAGE" == ghcr.io/geumyeongchoi/$APP:* ]] || { echo "denied image: $IMAGE" >&2; exit 2; }
export KUBECONFIG=/home/deploy/.kube/config
echo "deploy $APP ← $IMAGE"
kubectl -n "$APP" set image "deploy/$APP" app="$IMAGE"
if ! kubectl -n "$APP" rollout status "deploy/$APP" --timeout=240s; then
  echo "rollout failed → undo" >&2
  kubectl -n "$APP" rollout undo "deploy/$APP"
  kubectl -n "$APP" rollout status "deploy/$APP" --timeout=120s || true
  exit 1
fi
kubectl -n "$APP" get deploy "$APP" -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
