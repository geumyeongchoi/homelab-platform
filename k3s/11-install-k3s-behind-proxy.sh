#!/usr/bin/env bash
# k3s 단일 노드 설치 — 80/443 을 이미 다른 리버스 프록시(Nginx Proxy Manager 등)가 쓰는 서버용.
#  - Traefik 은 NodePort 30080/30443 으로만 열고, 앞단 프록시가 http://<host>:30080 으로 넘긴다 (TLS 는 앞단이 종료)
#  - servicelb(klipper) 비활성: 호스트 80/443 을 잡으려다 실패하는 노이즈 제거
#  - 메모리 8GB 서버: 4GB 스왑 파일 + kubelet fail-swap-on=false
#  - UFW: 파드/서비스 CIDR 허용, Docker 브리지(172.16/12) → 30080 허용. 6443 은 외부에 열지 않는다(로컬 kubectl 만).
# 멱등: 여러 번 실행해도 안전.
set -euo pipefail

SWAP_GB="${SWAP_GB:-4}"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l "${SWAP_GB}G" /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  sysctl -w vm.swappiness=10 >/dev/null; grep -q vm.swappiness /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
  echo "swap ${SWAP_GB}G on"
fi

# Traefik NodePort 설정은 k3s 가 기동하며 읽는 manifests 디렉터리에 먼저 둔다
mkdir -p /var/lib/rancher/k3s/server/manifests
cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml <<'YAML'
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    service:
      type: NodePort
    ports:
      web:
        nodePort: 30080
      websecure:
        nodePort: 30443
    # 앞단 프록시가 X-Forwarded-* 를 붙이므로 신뢰 대역 지정 (Docker 브리지)
    additionalArguments:
      - "--entryPoints.web.forwardedHeaders.trustedIPs=172.16.0.0/12,127.0.0.1/32"
      - "--entryPoints.web.proxyProtocol.trustedIPs=172.16.0.0/12,127.0.0.1/32"
    resources:
      requests: { cpu: 50m, memory: 64Mi }
      limits: { memory: 192Mi }
YAML

if command -v k3s >/dev/null; then
  echo "k3s already installed: $(k3s --version | head -1)"
else
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable servicelb --write-kubeconfig-mode 644 --kubelet-arg=fail-swap-on=false" sh -
fi

# UFW (활성인 경우만)
if ufw status | grep -q "Status: active"; then
  ufw allow from 10.42.0.0/16 comment 'k3s pods' >/dev/null
  ufw allow from 10.43.0.0/16 comment 'k3s services' >/dev/null
  ufw allow from 172.16.0.0/12 to any port 30080 proto tcp comment 'docker bridge -> traefik nodeport' >/dev/null
  ufw allow from 172.16.0.0/12 to any port 30443 proto tcp comment 'docker bridge -> traefik nodeport' >/dev/null
  echo "ufw rules added"
fi

mkdir -p ~/.kube && cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
command -v helm >/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null

echo "== waiting node ready"; for i in $(seq 1 30); do kubectl get nodes 2>/dev/null | grep -q ' Ready' && break; sleep 4; done
kubectl get nodes -o wide
echo "== waiting traefik"; for i in $(seq 1 45); do kubectl -n kube-system get svc traefik 2>/dev/null | grep -q NodePort && break; sleep 4; done
kubectl -n kube-system get svc traefik
echo "== nodeport check (404 from traefik = OK)"; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30080/ || true
echo "== mem"; free -h | head -2
