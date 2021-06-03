FROM --platform=$BUILDPLATFORM alpine AS build-amd64
WORKDIR /files
RUN apk add --update curl unzip
RUN \
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip -q awscliv2.zip && \
  rm awscliv2.zip
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee docker.list > /dev/null


FROM --platform=$BUILDPLATFORM alpine AS build-arm64
WORKDIR /files
RUN apk add --update curl unzip
RUN \
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
  unzip -q awscliv2.zip && \
  rm awscliv2.zip
RUN echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee docker.list > /dev/null


FROM build-${TARGETARCH} AS build


FROM ubuntu:18.04

# Install required base packages
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends curl cron ca-certificates apt-transport-https gnupg2 software-properties-common jq python3-pip && \
  apt-get clean && rm -rf /var/lib/apt/lists/* && \
  pip3 install --upgrade pip setuptools

# Install awscliv2 https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
COPY --from=build /files/aws ./aws
RUN \
  ./aws/install -i /usr/bin -b /usr/bin && \
  rm -rf ./aws && \
  aws --version

# Install Azure CLI
RUN pip3 install azure-cli

# Install docker CLI
COPY --from=build /files/docker.list /etc/apit/sources.list.d/docker.list
RUN \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
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
