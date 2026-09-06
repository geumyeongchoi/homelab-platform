# homelab-platform — 에이전트 작업 규칙 (SSOT)

## 스택
- k3s(최신 stable), Helm 3, kubectl, cert-manager, kube-prometheus-stack, Loki, Tempo, OpenTelemetry Collector, Sealed Secrets
- GitHub Actions, GHCR, jib(앱 저장소 측)
- 이 저장소는 **선언형 파일(yaml/helm values/workflow)** 과 스크립트만 담는다. 앱 코드 없음.

## HARD-GATE
1. 평문 Secret(`kind: Secret` with `data`/`stringData`) 커밋 금지 → SealedSecret만. pre-commit 훅 grep.
2. 서버에 직접 `kubectl apply`로 임시 변경 금지. 모든 변경은 저장소 파일 → `scripts/apply.sh`.
3. `kubeconfig`, 서버 IP, 도메인 실제 값은 `.env`(gitignore)에서만 읽는다. 문서엔 `<도메인>` 플레이스홀더.
4. 리소스 requests/limits 없는 Deployment 금지(단일 노드 OOM 방지).

## 디렉터리
```
k3s/            00-server-check.sh, 10-install-k3s.sh, 20-cert-manager.yaml, 30-cluster-issuer.yaml, whoami.yaml
helm/
  docmind/      Chart.yaml, values.yaml, templates/
  flashgate/    Chart.yaml, values.yaml, templates/
  values/       kube-prometheus-stack.yaml, loki.yaml, tempo.yaml, otel-collector.yaml
github-workflows/ deploy.yml   (앱 저장소 .github/workflows/ 로 복사해 사용)
otel/           collector-config.yaml
docs/           server.md(점검 결과), runbook.md(장애 대응), dashboards/*.json
scripts/        apply.sh, backup.sh, rollout-test.sh
```

## 작업 방식
- 각 스크립트는 멱등(재실행 안전). 실패 시 어느 단계인지 출력.
- 변경 후 `kubectl get pods -A` 전부 Running/Completed 확인을 DoD에 포함.
- 에이전트 서명 커밋 금지.
