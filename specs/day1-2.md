# Day 1~2 — 기반 구축

## Day 1 DoD
1. `k3s/00-server-check.sh` 결과 → `docs/server.md` (RAM에 따라 LGTM 범위 결정)
2. `k3s/10-install-k3s.sh` → `kubectl get nodes` Ready
3. cert-manager 설치, `ACME_EMAIL`·`DOMAIN` 환경변수로 `30-cluster-issuer.yaml` 적용
4. DNS `*.<도메인>` A 레코드 → 서버 IP
5. `https://whoami.<도메인>` 가 유효한 인증서로 200

## Day 2 DoD
1. `github-workflows/deploy.yml` 을 flashgate 저장소에 복사, jib 플러그인 추가, 시크릿/변수 등록 → 더미 Deployment(whoami 이미지)에 대해 파이프라인 green
2. Helm: `kube-prometheus-stack`(values: grafana ingress `grafana.<도메인>`, retention 7d, 리소스 제한), `loki`(single-binary, filesystem), `tempo`(single), `opentelemetry-collector`(otel/collector-config.yaml)
3. Grafana 로그인 → Explore에서 Prometheus/Loki/Tempo 데이터소스 3개 응답
4. `kubectl top nodes` 로 유휴 사용량 기록(앱 배포 전 기준선) → docs/server.md
