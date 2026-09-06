#!/usr/bin/env bash
# Day 10 — 롤링 배포 중 무중단 증명: k6 부하를 돌리면서 이미지 태그를 바꿔 rollout, 에러율 출력
# 사용: DOMAIN=example.com NEW_TAG=20260915-abc1234 scripts/rollout-test.sh
set -euo pipefail
: "${DOMAIN:?}" "${NEW_TAG:?}"
NS=flashgate; APP=flashgate
k6 run --quiet -e BASE_URL="https://flash.$DOMAIN" --duration 90s --vus 50 - <<'EOF' > /tmp/k6-rollout.txt &
import http from 'k6/http'; import { check } from 'k6';
export default function () { const r = http.get(`${__ENV.BASE_URL}/actuator/health`); check(r, { ok: (x) => x.status === 200 }); }
export function handleSummary(d) { return { stdout: `failed_rate=${d.metrics.http_req_failed.values.rate}\n` }; }
EOF
K6=$!
sleep 15
echo "[$(date +%T)] rolling to $NEW_TAG"
kubectl -n $NS set image deploy/$APP app="ghcr.io/${GH_USER:?}/flashgate:$NEW_TAG"
kubectl -n $NS rollout status deploy/$APP --timeout=120s
wait $K6
cat /tmp/k6-rollout.txt   # 기대: failed_rate=0
