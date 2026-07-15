# Custom Jenkins Controller with EKS/EMR Pipeline tools pre-installed
FROM jenkins/jenkins:lts

USER root

# Install standard base dependencies
RUN apt-get clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip \
    gnupg \
    git \
    && rm -rf /var/lib/apt/lists/*

# 1. Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip ./aws

# 2. Install HashiCorp Terraform
RUN curl -LO "https://releases.hashicorp.com/terraform/1.9.2/terraform_1.9.2_linux_amd64.zip" \
    && unzip terraform_1.9.2_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_1.9.2_linux_amd64.zip

# 3. Install Kubectl (match EKS K8s version 1.30)
RUN curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

# 4. Install Helm v3
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

# Switch back to the jenkins user for secure runtime execution
USER jenkins
