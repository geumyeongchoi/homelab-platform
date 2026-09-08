#!/usr/bin/env bash
# 앱 시크릿 생성(멱등). DB 비밀번호는 서버에서 생성해 /root/.secrets/ 에 보관, 모델 API 키는 /root/.docmind.env 에서 읽는다.
set -euo pipefail
mkdir -p /root/.secrets && chmod 700 /root/.secrets
pw() { [ -f "/root/.secrets/$1" ] || (umask 077; openssl rand -hex 16 > "/root/.secrets/$1"); cat "/root/.secrets/$1"; }
for ns in docmind flashgate; do kubectl create ns $ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null; done

kubectl -n flashgate get secret flashgate-secrets >/dev/null 2>&1 || \
  kubectl -n flashgate create secret generic flashgate-secrets --from-literal=DB_PASSWORD="$(pw flashgate-db)"

if [ -f /root/.docmind.env ]; then
  # /root/.docmind.env: OPENAI_API_KEY=... 또는 ANTHROPIC_API_KEY=...
  # kubectl 은 --from-env-file 과 --from-literal 을 섞을 수 없다 → 합친 env 파일을 임시로 만든다
  TMP=$(mktemp); chmod 600 "$TMP"; { echo "DB_PASSWORD=$(pw docmind-db)"; grep -E '^[A-Z_]+=' /root/.docmind.env; } > "$TMP"
  kubectl -n docmind create secret generic docmind-secrets --from-env-file="$TMP" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; rm -f "$TMP"
  echo "docmind-secrets: $(grep -oE '^[A-Z_]+' /root/.docmind.env | tr '\n' ' ')+ DB_PASSWORD"
else
  echo "docmind: /root/.docmind.env 없음 → docmind-secrets 생략 (모델 API 키 필요)"
fi
kubectl get secret -n flashgate -n docmind 2>/dev/null; kubectl get secret -A | grep -E "docmind-secrets|flashgate-secrets"
