# 서버 정보 (2026-09-07 점검)

| 항목 | 값 |
|---|---|
| 호스트 | vmi2992191 (VPS) · 공인 IP 38.242.198.168 |
| CPU / RAM / 디스크 | 4 vCPU · 7.8 GB · 291 GB (사용 22 GB) |
| OS / 커널 | Ubuntu 22.04.5 LTS · 5.15.0-161 (191 설치됨, 재부팅 대기) · x86_64 |
| 스왑 | 없음 → 설치 스크립트가 4 GB 스왑 파일 생성 |
| 기존 서비스 | Docker Compose 7 스택. **Nginx Proxy Manager 가 80/81/443 점유** → k3s Traefik 은 NodePort 30080/30443 뒤에 두고 NPM 이 프록시 |
| 정지한 스택 | seasparkle, self-hosted-ai-starter-kit(n8n·qdrant·postgres) — 사용자 확인 후 `docker compose stop`, 데이터 유지 |
| 방화벽 | UFW active (INPUT DROP). 6443 은 외부 비공개, 파드/서비스 CIDR 및 172.16/12→30080 허용 |

설치: `k3s/11-install-k3s-behind-proxy.sh` (멱등). 앞단 프록시 연결: NPM Proxy Host `docmind.<도메인>` → `http://<NPM 네트워크 게이트웨이 IP>:30080`.
