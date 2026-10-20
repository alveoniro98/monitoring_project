#!/usr/bin/env bash
set -Eeuo pipefail

exec > >(tee -a /var/log/opspulse-bootstrap.log | logger -t opspulse-bootstrap -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl snapd

if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
  snap install amazon-ssm-agent --classic
fi
snap start amazon-ssm-agent
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service

install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --location \
  https://download.docker.com/linux/ubuntu/gpg \
  --output /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
  "$(dpkg --print-architecture)" "$VERSION_CODENAME" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
install -d -o ubuntu -g docker /opt/opspulse

printf 'OpsPulse bootstrap completed at %s\n' "$(date --utc --iso-8601=seconds)"
