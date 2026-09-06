#!/usr/bin/env bash
# k3s 단일 노드 설치 (멱등). Traefik 내장 사용, 6443은 방화벽에서 관리자 IP만 허용할 것.
set -euo pipefail
if command -v k3s >/dev/null; then echo "k3s already installed: $(k3s --version | head -1)"; else
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -
fi
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown "$USER" ~/.kube/config
# GitHub Actions에서 쓸 kubeconfig: 서버 IP로 치환해 시크릿 KUBECONFIG_B64 에 저장
sed "s/127.0.0.1/$(curl -s https://ifconfig.me)/" ~/.kube/config | base64 -w0 > ~/kubeconfig.b64
echo "kubeconfig for CI → ~/kubeconfig.b64 (GitHub secret KUBECONFIG_B64 에 등록 후 파일 삭제)"
# Helm
command -v helm >/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
kubectl get nodes
