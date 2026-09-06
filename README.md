# homelab-platform — 자체 서버 k3s · CI/CD · 관측 · HTTPS 도메인

> docmind와 flashgate를 **내 Linux 서버의 k3s**에 올리고, PR 머지 한 번으로 HTTPS 도메인까지 배포되며, 두 서비스의 로그·메트릭·트레이스를 Grafana 한 화면에서 보는 플랫폼.
> 문제가 생겼을 때 로그·메트릭·트레이스를 따로 뒤지지 않고 요청 하나의 흐름을 한 화면에서 따라가는 관측 환경을 직접 서버에 구축하는 것이 출발점.

## 1. 구성

```
GitHub (docmind / flashgate PR 머지)
   │ GitHub Actions: test → jib 이미지 → GHCR push → kubectl set image (SSH/kubeconfig 시크릿)
   ▼
[Linux 서버]  k3s (single node, Traefik ingress 내장)
   ├─ cert-manager + Let's Encrypt  → *.<도메인> HTTPS
   ├─ ns docmind    : docmind Deployment(1) + pgvector StatefulSet
   ├─ ns flashgate  : flashgate Deployment(2, PDB minAvailable=1, HPA cpu 70%) + redis(sentinel) + kafka + mysql
   ├─ ns observability :
   │     kube-prometheus-stack (Prometheus·Grafana·Alertmanager)
   │     Loki(+ Alloy 로그 수집)  ·  Tempo(트레이스)  ·  OTel Collector(OTLP 수신)
   └─ ns platform   : sealed-secrets, whoami(연결 확인)

  https://docmind.<도메인>   https://flash.<도메인>   https://grafana.<도메인>
```

## 2. 설계 판단

| 결정 | 대안 | 이유 |
|---|---|---|
| k3s | Docker Compose, kubeadm, EKS | Compose는 K8s 키워드를 못 잡고, kubeadm은 설치가 하루, EKS는 월 $70+. k3s는 10분 설치·Traefik 내장·리소스 512MB |
| GHCR + `kubectl set image` | ArgoCD(GitOps) | 12일 안에는 push형이 현실적. ArgoCD는 Day 12 이후 "다음 단계"로 README에 명시 |
| OTel Java agent 자동계측 | Micrometer 수동 계측만 | 코드 변경 없이 HTTP/JDBC/Kafka/Redis 스팬 확보. 앱은 OTLP 엔드포인트만 알면 됨 |
| Loki+Tempo(LGTM) | ELK | 메모리 1/4, Grafana 하나로 3신호 상관 조회(trace_id 클릭 → 로그) |
| Sealed Secrets | 평문 Secret yaml, Vault | 저장소 공개 가능 + 설치 1분 |

## 3. 범위

**Day 1** — 서버 준비, k3s, cert-manager, 도메인
**Day 2** — GitHub Actions 파이프라인, kube-prometheus-stack, Loki, Tempo
**Day 9** — docmind/flashgate Helm 차트, HPA/PDB/probe, OTel agent 주입
**Day 10** — 롤링 배포 중 k6 → 에러율 0 증명, 대시보드 코드화(JSON in repo)
**Day 11** — 통합 점검, 백업(`k3s etcd-snapshot` + DB dump cron), Sealed Secrets

**WON'T**: 멀티 노드, ArgoCD, 서비스 메시, 알림 채널 연동(Alertmanager 규칙만 작성)

## 4. 서버 요구사항

| 항목 | 최소 | 권장 |
|---|---|---|
| CPU/RAM | 2 vCPU / 4GB (LGTM 제외) | **4 vCPU / 8GB** |
| 디스크 | 40GB | 80GB SSD |
| OS | Ubuntu 22.04+/Debian 12/Rocky 9 | Ubuntu 24.04 |
| 포트 | 80, 443 인바운드, 6443(관리자 IP만) | |
| DNS | `*.<도메인>` A 레코드 → 서버 IP | |

착수 전 `scripts/00-server-check.sh` 실행 결과를 `docs/server.md`에 기록.

## 5. 이력서/면접 포인트
- "쿠버네티스 실무 경험?" → 단일 노드지만 Deployment·HPA·PDB·probe·Ingress·cert-manager·Helm·Secret 관리를 직접 운영, 롤링 배포 무중단 수치.
- "관측은 어떻게?" → OTel → Tempo/Loki/Prometheus, trace_id로 로그↔트레이스 연결, RED 대시보드.
- "CI/CD?" → PR 머지 → __분 내 배포, 실패 시 자동 롤백(`kubectl rollout undo`) 스텝.
