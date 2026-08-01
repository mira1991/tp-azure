# Image toolbox de la pipeline — toutes les versions sont épinglées.
# Publication attendue : ${CI_REGISTRY_IMAGE}/toolbox:<version> (cf. Makefile).
FROM python:3.12.7-slim-bookworm

ARG TERRAFORM_VERSION=1.9.8
ARG TFLINT_VERSION=0.53.0
ARG GITLEAKS_VERSION=8.18.4
ARG YQ_VERSION=4.44.3
# Doivent rester alignés avec kolla/versions/{source,target}.yml.
ARG KOLLA_SOURCE_VERSION=18.4.0
ARG KOLLA_SOURCE_ANSIBLE_CORE=2.16.14
ARG KOLLA_TARGET_VERSION=19.3.0
ARG KOLLA_TARGET_ANSIBLE_CORE=2.17.7

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        openssh-client \
        rsync \
        sshpass \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Certificats CA internes : déposer les .crt dans ci/ca-certificates/ avant
# le build (répertoire vide accepté).
COPY ca-certificates/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

RUN curl -fsSLo /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip /tmp/terraform.zip -d /usr/local/bin terraform \
    && rm /tmp/terraform.zip \
    && terraform version

RUN curl -fsSLo /tmp/tflint.zip \
        "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    && unzip /tmp/tflint.zip -d /usr/local/bin tflint \
    && rm /tmp/tflint.zip

RUN curl -fsSL \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    | tar -xz -C /usr/local/bin gitleaks

RUN curl -fsSLo /usr/local/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    && chmod 0755 /usr/local/bin/yq

# Outillage Python épinglé (lint, tests, OpenStack CLI, ansible-lint...).
COPY requirements.txt /opt/toolbox/requirements.txt
RUN pip install --require-hashes --no-deps -r /opt/toolbox/requirements.txt 2>/dev/null \
    || pip install -r /opt/toolbox/requirements.txt

# Deux venvs Kolla-Ansible (source et cible) pour l'upgrade sans
# réinstallation : sélection par KOLLA_VENV=source|target (entrypoint).
RUN python3 -m venv /opt/kolla/source \
    && /opt/kolla/source/bin/pip install \
        "kolla-ansible==${KOLLA_SOURCE_VERSION}" \
        "ansible-core==${KOLLA_SOURCE_ANSIBLE_CORE}" \
    && python3 -m venv /opt/kolla/target \
    && /opt/kolla/target/bin/pip install \
        "kolla-ansible==${KOLLA_TARGET_VERSION}" \
        "ansible-core==${KOLLA_TARGET_ANSIBLE_CORE}"

# Collections requises par les playbooks du dépôt, dans chaque venv.
RUN /opt/kolla/source/bin/ansible-galaxy collection install \
        ansible.posix community.general \
    && /opt/kolla/target/bin/ansible-galaxy collection install \
        ansible.posix community.general

COPY entrypoint.sh /usr/local/bin/toolbox-entrypoint
RUN chmod 0755 /usr/local/bin/toolbox-entrypoint

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/toolbox-entrypoint"]
CMD ["bash"]
