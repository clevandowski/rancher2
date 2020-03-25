FROM ubuntu:18.04

ENV HELM_VERSION v3.1.2
# ENV RKE_VERSION v1.0.0

RUN apt-get update \
    && apt-get install -y curl unzip python-pip openssh-client bash-completion jq iproute2 net-tools groff xxd iputils-ping dnsutils vim git gettext-base \
    && apt-get clean all \
    && apt-get autoclean all \
# TERRAFORM
# https://learn.hashicorp.com/terraform/getting-started/install.html
    && TERRAFORM_VERSION=$(curl -s https://releases.hashicorp.com/terraform/ | grep -o "terraform_[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1 | sed -e "s|.*_\([0-9]\+\.[0-9]\+\.[0-9]\+$\)|\1|") \
    && curl -LOs https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip --output terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && chmod +x terraform \
    && mv terraform /usr/local/bin \
    && terraform -install-autocomplete \
# KUBECTL
# https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl
    && curl -LOs https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin \
#    && source <\(kubectl completion bash\) \
# HELM
# https://rancher.com/docs/rancher/v2.x/en/installation/options/helm-version/
# Décommenter la ligne suivante quand on peut passer à HELM v3
#    && HELM_VERSION=$(curl -sf "https://github.com/helm/helm/releases/latest" | sed -e "s|^.*href=\"https://github.com/helm/helm/releases/tag/\([^\"]*\)\".*$|\1|") \
    && curl -LOs https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && tar xvf helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz \
# RKE
# https://rancher.com/docs/rke/latest/en/installation/
    && RKE_VERSION=$(curl -sf "https://github.com/rancher/rke/releases/latest" | sed -e "s|^.*href=\"https://github.com/rancher/rke/releases/tag/\([^\"]*\)\".*$|\1|") \
    && curl -LOs https://github.com/rancher/rke/releases/download/${RKE_VERSION}/rke_linux-amd64 \
    && mv rke_linux-amd64 /usr/local/bin/rke \
    && chmod +x /usr/local/bin/rke \
# RANCHER_CLI
# https://rancher.com/docs/rancher/v2.x/en/cli/
    && RANCHER_CLI_VERSION=$(curl -sf "https://github.com/rancher/cli/releases/latest" | sed -e "s|^.*href=\"https://github.com/rancher/cli/releases/tag/\([^\"]*\)\".*$|\1|") \
    && curl -LOs https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz \
    && tar xvf rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz \
    && mv rancher-${RANCHER_CLI_VERSION}/rancher /usr/local/bin/rancher \
    && chmod +x /usr/local/bin/rancher \
    && rm -rf rancher-${RANCHER_CLI_VERSION} rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz

ARG USER_ID
ARG GROUP_ID
ARG USER_NAME
ARG GROUP_NAME

# Add group if not present
# Add user if not present
RUN if getent group ${GROUP_ID} >/dev/null; then \
      echo "Group ${GROUP_ID} already exists"; \
    else \
      echo "Creating group ${GROUP_ID}"; \
      groupadd -g ${GROUP_ID} ${GROUP_NAME}; \
    fi \
    && if getent passwd ${USER_ID} >/dev/null; then \
      echo "User ${USER_ID} already exists"; \
    else \
      echo "Creating user ${USER_ID}"; \
      useradd -u ${USER_ID} -g ${GROUP_ID} ${USER_NAME} --create-home; \
    fi

WORKDIR /home/${USER_NAME}
USER ${USER_ID}

# RUN mkdir -p /home/${USER_NAME}/.local && \
RUN pip install awscli --upgrade --user \
    && pip install ansible --upgrade --user
#    && complete -C ~/.local/bin/aws_completer aws

ENV PATH ${PATH}:/home/${USER_NAME}/.local/bin:~${USER_NAME}/bin
ENV TF_PLUGIN_CACHE_DIR /home/${USER_NAME}/.terraform.d/plugin-cache
