FROM mcr.microsoft.com/dotnet/sdk:9.0-noble AS build
ARG BUILD_AZP_TOKEN
ARG BUILD_AZP_URL
ARG BUILD_AZP_VERSION=1.0.0.0

ENV TARGETARCH="linux-x64"
ENV VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"
ENV BUILD_AZP_VERSION="${BUILD_AZP_VERSION}"

LABEL "io.containers.capabilities"="CHOWN,DAC_OVERRIDE,FOWNER,FSETID,KILL,NET_BIND_SERVICE,SETFCAP,SETGID,SETPCAP,SETUID,CHOWN,DAC_OVERRIDE,FOWNER,FSETID,KILL,NET_BIND_SERVICE,SETFCAP,SETGID,SETPCAP,SETUID,SYS_CHROOT"

USER root

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl git jq libicu74 wget apt-transport-https software-properties-common
RUN apt-get install -y zip python3 python3-pip unzip

# Install Buildah
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
    && DEBIAN_FRONTEND=noninteractive \
    && dpkg --configure -a \
    && apt-get install -y tzdata \
    && apt-get install -y buildah \
    && apt-get install fuse-overlayfs

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && az upgrade --all --yes

WORKDIR /azp/

COPY ./install.sh /azp/
COPY ./start.sh /azp/
COPY ./primedotnet.ps1 /azp/
COPY ./installsqltools.sh /azp/

RUN chmod +x ./install.sh \
    && chmod +x ./start.sh \
    && chmod +x ./primedotnet.ps1 \
    && chmod +x installsqltools.sh \
    && adduser --disabled-password agent \
    && chown -R agent ./

# Add necessary configuration for Buildah
RUN mkdir -p /home/agent/.local/share/containers \
    && mkdir -p /var/lib/containers \
    && mkdir -p /etc/containers/ \
    && mkdir -p /home/agent/.config/containers \
    && chown agent:agent -R /home/agent \
    && chown agent:agent -R /home/agent/.local \
    && chown agent:agent -R /var/lib/containers \
    && chown agent:agent -R /home/agent/.config/containers \
    && usermod --add-subuids 100000-200000 --add-subgids 100000-200000 agent

RUN printf '/run/secrets/etc-pki-entitlement:/run/secrets/etc-pki-entitlement\n/run/secrets/rhsm:/run/secrets/rhsm\n' > /etc/containers/mounts.conf

RUN mkdir -p /var/lib/shared/overlay-images \
             /var/lib/shared/overlay-layers \
             /var/lib/shared/vfs-images \
             /var/lib/shared/vfs-layers && \
    touch /var/lib/shared/overlay-images/images.lock && \
    touch /var/lib/shared/overlay-layers/layers.lock && \
    touch /var/lib/shared/vfs-images/images.lock && \
    touch /var/lib/shared/vfs-layers/layers.lock

VOLUME /var/lib/containers
VOLUME /home/agent/.local/share/containers

ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot

ADD ./Buildah/storage.conf /usr/share/containers/
ADD ./Buildah/containers.conf /etc/containers/

RUN sed -e 's|^#mount_program|mount_program|g' \
        -e '/additionalimage.*/a "/var/lib/shared",' \
        -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' \
        /usr/share/containers/storage.conf \
        > /etc/containers/storage.conf && \
    chmod 644 /etc/containers/storage.conf && \
    chmod 644 /etc/containers/containers.conf

RUN sed -e 's|^#mount_program|mount_program|g' \
        -e 's|^graphroot|#graphroot|g' \
        -e 's|^runroot|#runroot|g' \
        /etc/containers/storage.conf \
        > /home/agent/.config/containers/storage.conf && \
        chown agent:agent /home/agent/.config/containers/storage.conf

# Install MS SQL Tools / Drivers
ENV PATH="${PATH}:/opt/mssql-tools18/bin/"
RUN ./installsqltools.sh \
    && sqlcmd "-?"

USER agent

# Install Node
ENV FNM_PATH="/home/agent/.local/share/fnm"
ENV PATH="${PATH}:${FNM_PATH}"
RUN curl -fsSL https://fnm.vercel.app/install | bash 
RUN eval "$(fnm env --shell bash)"\
    && fnm install 18 \
    && fnm install 20 \
    && fnm install 22 \
    && fnm install --lts \
    && fnm default 22 \
    && node -v \
    && npm --version

ENV AGENT_TOOLSDIRECTORY="/azp/tools"
RUN mkdir /azp/tools

# Install .NET
ENV NUGET_PACKAGES="/azp/nuget/NUGET_PACKAGES"
ENV NUGET_HTTP_CACHE_PATH="/azp/nuget/NUGET_HTTP_CACHE_PATH"
ENV PATH="/azp/tools/dotnet:${PATH}"
ENV DOTNET_ROOT="/azp/tools/dotnet"
ENV DOTNET_HOST_PATH="/azp/tools/dotnet/dotnet"
RUN mkdir /azp/nuget \
    && mkdir /azp/nuget/NUGET_PACKAGES \
    && mkdir /azp/nuget/NUGET_HTTP_CACHE_PATH \
    && mkdir /azp/tools/dotnet \
    && curl -Lsfo "dotnet-install.sh" https://dot.net/v1/dotnet-install.sh \
    && chmod +x "dotnet-install.sh" \
    && ./dotnet-install.sh --channel 3.1 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 6.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 7.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 8.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 9.0 --install-dir /azp/tools/dotnet

# Install DevOps Agent
RUN export AZP_TOKEN=${BUILD_AZP_TOKEN} \
    && export AZP_URL=${BUILD_AZP_URL} \
    && ./install.sh

# Configure Node, Install Azurite & Renovate
ENV PATH="${PATH}:/home/agent/.npm-global/bin"
RUN eval "$(fnm env --shell bash)" \
    && mkdir /home/agent/.npm-global \
    && npm --version 
    # && npm config set prefix '/home/agent/.npm-global' \
    # && npm install -g azurite \
    # && npm install -g renovate

# Install Global tools
ENV PATH="${PATH}:/home/agent/.dotnet/tools"
RUN dotnet tool install --global dpi \
    && dpi --version \
    && dotnet tool install --global Cake.Tool \
    && dotnet cake --info \
    && dotnet tool install --global microsoft.sqlpackage \
    && sqlpackage /version \
    && dotnet tool install --global dotnet-outdated-tool \
    && dotnet-outdated --version \
    && dotnet tool install --global azdomerger

# Prime .NET
# RUN ./primedotnet.ps1

ENTRYPOINT ./start.sh
