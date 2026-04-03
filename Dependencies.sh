#!/bin/bash
set -e

echo "===== Updating system ====="
sudo apt update -y

echo "===== Installing Java 17 ====="
sudo apt install -y openjdk-17-jre
java -version

echo "===== Installing Jenkins ====="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
| sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update -y
sudo apt install -y jenkins
sudo systemctl enable --now jenkins

echo "===== Installing Docker ====="
sudo apt install -y docker.io
sudo systemctl enable --now docker

# Add users to docker group (ignore if user doesn't exist)
sudo usermod -aG docker ubuntu 2>/dev/null || true
sudo usermod -aG docker jenkins

echo "===== Installing AWS CLI v2 ====="
sudo apt remove -y awscli || true
sudo apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -o awscliv2.zip
sudo ./aws/install
aws --version

echo "===== Installing kubectl ====="
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

echo "===== Installing eksctl ====="
curl --silent --location \
"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
| tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

echo "===== Installing Trivy ====="
sudo apt install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
| sudo tee /etc/apt/sources.list.d/trivy.list

sudo apt update -y
sudo apt install -y trivy
trivy --version

echo "✅ All tools installed successfully"
