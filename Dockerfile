FROM --platform=$BUILDPLATFORM alpine AS build-amd64
WORKDIR /files
RUN apk add --update curl unzip
RUN \
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip -q awscliv2.zip && \
  rm awscliv2.zip


FROM --platform=$BUILDPLATFORM alpine AS build-arm64
WORKDIR /files
RUN apk add --update curl unzip
RUN \
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
  unzip -q awscliv2.zip && \
  rm awscliv2.zip


FROM build-${TARGETARCH} AS build


FROM ubuntu:18.04
ARG TARGETARCH

# Install required base packages
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends curl cron ca-certificates apt-transport-https gnupg2 software-properties-common jq && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install awscliv2 https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
COPY --from=build /files/aws ./aws
RUN \
  ./aws/install -i /usr/bin -b /usr/bin && \
  rm -rf ./aws && \
  aws --version

# Install Azure CLI
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends python3-dev python3-pip gcc libffi-dev && \
  pip3 install --upgrade pip setuptools && \
  pip3 install azure-cli && \
  apt-get autoremove -y python3-dev gcc libffi-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install docker CLI
RUN \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo "deb [arch=${TARGETARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y --no-install-recommends docker-ce-cli && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy scripts and allow execution
COPY ./src/entrypoint.sh ./src/backup.sh /root/
RUN \
  chmod a+x /root/entrypoint.sh && \
  chmod a+x /root/backup.sh

WORKDIR /root
CMD [ "/root/entrypoint.sh" ]
