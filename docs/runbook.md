# Runbook — 장애 대응 (Day 11에 실제 겪은 항목으로 갱신)

| 증상 | 확인 | 조치 |
|---|---|---|
| 도메인 접속 불가 | `kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik`, `kubectl get certificate -A` | cert 미발급이면 `kubectl describe challenge -A`(80포트 개방·DNS 전파 확인) |
| 배포 후 Pod CrashLoop | `kubectl -n <ns> logs deploy/<app> --previous` | 설정/시크릿 누락이 대부분. `rollout undo` 후 원인 수정 |
| flashgate 503 급증 | Grafana `resilience4j_circuitbreaker_state`, `redis-sentinel` 로그 | Sentinel failover 진행 중이면 3~10초 내 자동 복구. 지속되면 Redis Pod 상태 확인 |
| 재고 불일치 알람 | `flashgate_stock_mismatch==1` | ReconcileJob 로그로 차이값 확인, DLT 토픽 메시지 확인 후 수동 보상 |
| docmind 응답 없음 | `/api/health/ai` | public 모드 API 키 만료/한도 → Secret 갱신 후 rollout restart |
| 노드 디스크 부족 | `df -h`, `crictl images` | `k3s crictl rmi --prune`, Loki retention 축소 |
| 전체 복구 | `k3s etcd-snapshot ls` | `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>` |
