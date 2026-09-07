#!/usr/bin/env bash
# CI 배포 전용 사용자: 셸 접근 없이 scripts/remote-deploy.sh 만 실행되는 forced-command 키. 멱등.
set -euo pipefail
REPO_DIR="${REPO_DIR:-/root/homelab-platform}"
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh /home/deploy/.kube
install -m 600 -o deploy -g deploy /etc/rancher/k3s/k3s.yaml /home/deploy/.kube/config
install -m 755 "$REPO_DIR/scripts/remote-deploy.sh" /usr/local/bin/remote-deploy.sh
[ -f /root/.ssh/deploy_ed25519 ] || ssh-keygen -t ed25519 -N "" -C "github-actions-deploy" -f /root/.ssh/deploy_ed25519 -q
PUB=$(cat /root/.ssh/deploy_ed25519.pub)
echo "command=\"/usr/local/bin/remote-deploy.sh\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $PUB" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys; chmod 600 /home/deploy/.ssh/authorized_keys
echo "deploy user ready. private key: /root/.ssh/deploy_ed25519 → GitHub secret DEPLOY_SSH_KEY (앱 저장소마다), variable DEPLOY_HOST=<서버IP>"
