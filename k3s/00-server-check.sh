#!/usr/bin/env bash
# Day 1 첫 명령. 결과를 docs/server.md 에 붙여넣는다.
set -u
echo "## OS";        cat /etc/os-release | head -3
echo "## CPU/RAM";   nproc; free -h
echo "## Disk";      df -h / | tail -1
echo "## Kernel";    uname -r
echo "## Public IP"; curl -s https://ifconfig.me || true; echo
echo "## Ports 80/443/6443 in use?"; (ss -ltnp 2>/dev/null || netstat -ltnp) | grep -E ':80 |:443 |:6443 ' || echo "free"
echo "## Docker/containerd?"; command -v docker && docker --version || echo "no docker (k3s는 자체 containerd 사용, 문제 없음)"
echo "## swap (k8s는 swap off 권장)"; swapon --show || echo "off"
echo "## cgroup v2?"; stat -fc %T /sys/fs/cgroup/
echo
echo "판단 기준: RAM 8GB↑ → LGTM 전체 / 4GB → Prometheus+Grafana만(Loki·Tempo 생략) / 2GB → 이 프로젝트 범위 축소 필요"
