FROM ubuntu:26.04 AS build
ARG BUILD_AZP_TOKEN
ARG BUILD_AZP_URL
ARG BUILD_AZP_VERSION=1.0.0.0

ENV TARGETARCH="linux-x64" \
    VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE" \
    BUILD_AZP_VERSION="${BUILD_AZP_VERSION}" \
    TOOL_VERSIONS_FILE="/azp/tool-versions.tsv"

LABEL "io.containers.capabilities"="CHOWN,DAC_OVERRIDE,FOWNER,FSETID,KILL,NET_BIND_SERVICE,SETFCAP,SETGID,SETPCAP,SETUID,CHOWN,DAC_OVERRIDE,FOWNER,FSETID,KILL,NET_BIND_SERVICE,SETFCAP,SETGID,SETPCAP,SETUID,SYS_CHROOT"

USER root

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages, Buildah, Skopeo, kubectl, and SQL tools
ENV PATH="${PATH}:/opt/mssql-tools18/bin/"
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
    && dpkg --configure -a \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        buildah \
        bzip2 \
        ca-certificates \
        clang \
        curl \
        fuse-overlayfs \
        git \
        gnupg \
        jdupes \
        jq \
        libicu78 \
        libssl3t64 \
        llvm \
        python3 \
        python3-pip \
        skopeo \
        software-properties-common \
        tzdata \
        unzip \
        wget \
        zip \
        zlib1g-dev \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list \
    && chmod 644 /etc/apt/sources.list.d/kubernetes.list \
    && curl -fsSL -o /tmp/packages-microsoft-prod.deb \
        https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm -f /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        kubectl \
        msodbcsql18 \
        mssql-tools18 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && az upgrade --all --yes \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Azure Developer CLI
RUN curl -fsSL https://aka.ms/install-azd.sh | bash \
    && azd version \
    && rm -rf /tmp/* /var/tmp/*

# Install Bicep
RUN curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x bicep \
    && mv bicep /usr/local/bin/ \
    && az config set bicep.check_version=False \
    && az config set bicep.use_binary_from_path=True \
    && bicep --version \
    && az bicep version

# Install regctl
RUN curl -Lo regctl https://github.com/regclient/regclient/releases/latest/download/regctl-linux-amd64 \
    && chmod +x regctl \
    && mv regctl /usr/local/bin/ \
    && regctl version

# Install go-sqlcmd
RUN curl -Lo sqlcmd.tar.bz2 https://github.com/microsoft/go-sqlcmd/releases/latest/download/sqlcmd-linux-amd64.tar.bz2 \
    && tar -xjf sqlcmd.tar.bz2 sqlcmd \
    && chmod +x sqlcmd \
    && mv sqlcmd /usr/local/bin/ \
    && rm sqlcmd.tar.bz2 \
    && sqlcmd --version

WORKDIR /azp/

COPY ./install.sh /azp/
COPY ./start.sh /azp/
COPY ./primedotnet.ps1 /azp/
COPY ./crane.sh /azp/
COPY ./recordversion.sh /azp/

RUN chmod +x ./install.sh \
    && chmod +x ./start.sh \
    && chmod +x ./primedotnet.ps1 \
    && chmod +x ./crane.sh \
    && chmod +x ./recordversion.sh \
    && : > "${TOOL_VERSIONS_FILE}" \
    && adduser --disabled-password agent \
    && chown -R agent ./

# Record versions installed before the recorder was available
RUN ./recordversion.sh azd azd version \
    && ./recordversion.sh bicep bicep --version \
    && ./recordversion.sh "az bicep" az bicep version \
    && ./recordversion.sh regctl regctl version \
    && ./recordversion.sh sqlcmd sqlcmd --version

# Configuration for Skopeo
RUN mkdir -p /run/containers \
    && chown agent:agent -R /run/containers \
    && chmod 644 /run/containers

# Add necessary configuration for Buildah
RUN mkdir -p /home/agent/.local/share/containers \
    && mkdir -p /var/lib/containers \
    && mkdir -p /etc/containers/ \
    && mkdir -p /home/agent/.config/containers \
    && mkdir -p /home/agent/.azure/bin \
    && ln -sfn /usr/local/bin/bicep /home/agent/.azure/bin/bicep \
    && HOME=/home/agent az config set bicep.check_version=False \
    && HOME=/home/agent az config set bicep.use_binary_from_path=True \
    && chown agent:agent -R /home/agent \
    && chown agent:agent -R /home/agent/.local \
    && chown agent:agent -R /var/lib/containers \
    && chown agent:agent -R /home/agent/.config/containers \
    && usermod --add-subuids 100000-165535 --add-subgids 100000-165535 agent

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

ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot REGISTRY_AUTH_FILE=/home/agent/auth.json

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
        chown agent:agent /home/agent/.config/containers/storage.conf && \
        chmod 4755 /usr/bin/newuidmap /usr/bin/newgidmap

# Install crane
RUN ./crane.sh

USER agent

# Install Node, Azurite, Renovate, Cursor, and Claude in one layer for jdupes.
# Tasks such as PublishTestResults still declare a Node 20 handler. EOL agent
# runtimes are removed after install; run those handlers on the bundled Node 24.
ENV FNM_PATH="/home/agent/.local/share/fnm" \
    PNPM_HOME="/home/agent/.local/share/pnpm" \
    PATH="${PATH}:/home/agent/.local/share/fnm:/home/agent/.local/share/pnpm:/home/agent/.npm-global/bin:/home/agent/.local/bin" \
    AGENT_USE_NODE24=true \
    AGENT_USE_NODE24_WITH_HANDLER_DATA=true
RUN curl -fsSL https://fnm.vercel.app/install | bash \
    && eval "$(fnm env --shell bash)" \
    && fnm install 22 \
    && fnm install 24 \
    && fnm install --lts \
    && fnm default 24 \
    && ./recordversion.sh node node -v \
    && ./recordversion.sh "npm (initial)" npm --version \
    && npm install -g pnpm \
    && ./recordversion.sh pnpm pnpm --version \
    && mkdir /home/agent/.npm-global \
    && mkdir -p "${PNPM_HOME}" \
    && fnm use 24 --install-if-missing \
    && ./recordversion.sh "npm (node 24)" npm --version \
    && npm config set prefix '/home/agent/.npm-global' \
    && npm install -g azurite \
    && npm install -g typescript-language-server typescript \
    && mkdir -p /tmp/renovate-install \
    && cd /tmp/renovate-install \
    && npm exec --yes --package=pnpm@11 pnpm -- add --global --global-bin-dir "${PNPM_HOME}" --allow-build=re2 renovate@latest \
    && /azp/recordversion.sh renovate renovate --version \
    && export RE2_PKG="$(find "${PNPM_HOME}" -type d -path '*/node_modules/re2' | head -n 1)" \
    && test -n "${RE2_PKG}" \
    && node -e "new (require(process.env.RE2_PKG))('.*').exec('test')" \
    && curl -fsSL https://cursor.com/install | bash \
    && /azp/recordversion.sh cursor-agent cursor-agent --version \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && /azp/recordversion.sh claude claude --version \
    && claude plugin marketplace add anthropics/claude-plugins-official \
    && claude plugin marketplace add dotnet/skills \
    && claude plugin install dotnet \
    && claude plugin install dotnet-data \
    && claude plugin install dotnet-diag \
    && claude plugin install dotnet-msbuild \
    && claude plugin install dotnet-nuget \
    && claude plugin install dotnet-upgrade \
    && claude plugin install dotnet-maui \
    && claude plugin install dotnet-ai \
    && claude plugin install dotnet-template-engine \
    && claude plugin install dotnet-test \
    && claude plugin install typescript-lsp \
    && npm cache clean --force \
    && pnpm store prune \
    && rm -rf /tmp/renovate-install /tmp/npm-* /home/agent/.npm /tmp/fnm* \
    && jdupes -r -L -t /home/agent/.local/share /home/agent/.npm-global

# Install Playwright browser system dependencies
USER root
RUN export FNM_DIR="${FNM_PATH}" \
    && eval "$(fnm env --shell bash)" \
    && export DEBIAN_FRONTEND=noninteractive \
    && export npm_config_cache=/tmp/playwright-npm-cache \
    && playwright_version="$(npm view playwright version)" \
    && npx --yes "playwright@${playwright_version}" install-deps \
    && ./recordversion.sh "playwright deps" echo "${playwright_version}" \
    && rm -rf /tmp/* /root/.npm /var/lib/apt/lists/* /var/cache/apt/archives/*
USER agent

ENV AGENT_TOOLSDIRECTORY="/azp/tools"
RUN mkdir /azp/tools

# Publish PowerShell on usual /usr paths; install later fills these in
USER root
RUN ln -sfn /azp/tools/powershell /usr/share/powershell \
    && ln -sfn /azp/tools/powershell/pwsh /usr/bin/pwsh
USER agent

# Install .NET SDKs, PowerShell, global tools, and prime NuGet in one layer
ENV NUGET_PACKAGES="/azp/nuget/NUGET_PACKAGES" \
    NUGET_HTTP_CACHE_PATH="/azp/nuget/NUGET_HTTP_CACHE_PATH" \
    PATH="/azp/tools/dotnet:${PATH}:/home/agent/.dotnet/tools" \
    DOTNET_ROOT="/azp/tools/dotnet" \
    DOTNET_HOST_PATH="/azp/tools/dotnet/dotnet" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false \
    DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE=1 \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off
RUN mkdir /azp/nuget \
    && mkdir /azp/nuget/NUGET_PACKAGES \
    && mkdir /azp/nuget/NUGET_HTTP_CACHE_PATH \
    && mkdir /azp/tools/dotnet \
    && curl -Lsfo "dotnet-install.sh" https://dot.net/v1/dotnet-install.sh \
    && chmod +x "dotnet-install.sh" \
    && ./dotnet-install.sh --channel 8.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 9.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 10.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 11.0 --quality preview --install-dir /azp/tools/dotnet \
    && rm -f dotnet-install.sh \
    && powershell_version="$(curl -fsSL https://aka.ms/pwsh-buildinfo-stable \
        | jq -er '.ReleaseTag | ltrimstr("v")')" \
    && curl --fail --show-error --location --output "/tmp/PowerShell.Linux.x64.${powershell_version}.nupkg" \
        "https://powershellinfraartifacts-gkhedzdeaghdezhr.z01.azurefd.net/tool/${powershell_version}/PowerShell.Linux.x64.${powershell_version}.nupkg" \
    && /azp/tools/dotnet/dotnet tool install --add-source /tmp --tool-path /azp/tools/powershell --version "${powershell_version}" PowerShell.Linux.x64 \
    && rm -f "/tmp/PowerShell.Linux.x64.${powershell_version}.nupkg" \
    && chmod 755 /azp/tools/powershell/pwsh \
    && chmod 755 /azp/tools/powershell/.store/powershell.linux.x64/${powershell_version}/powershell.linux.x64/${powershell_version}/tools/*/any/pwsh \
    && find /azp/tools/powershell -iname '*.nupkg' -delete \
    && ./recordversion.sh pwsh pwsh --version \
    && dotnet tool install --global dpi \
    && ./recordversion.sh dpi dpi --version \
    && dotnet tool install --global Cake.Tool \
    && ./recordversion.sh Cake dotnet cake --version \
    && dotnet tool install --global microsoft.sqlpackage \
    && ./recordversion.sh sqlpackage sqlpackage /version \
    && dotnet tool install --global dotnet-outdated-tool \
    && ./recordversion.sh dotnet-outdated dotnet-outdated --version \
    && dotnet tool install --global azdomerger \
    && dotnet tool install --global roslyn-language-server --prerelease \
    && dotnet new install xunit.v3.templates \
    && dotnet new list xunit3 \
    && ./primedotnet.ps1 \
    && jdupes -r -L -t /azp/tools/dotnet /azp/tools/powershell /home/agent/.dotnet/tools /azp/nuget

# Install DevOps Agent
RUN export AZP_TOKEN=${BUILD_AZP_TOKEN} \
    && export AZP_URL=${BUILD_AZP_URL} \
    && ./install.sh \
    && rm -rf /azp/externals/node /azp/externals/node[0-9]* \
    && eval "$(fnm env --shell bash)" \
    && fnm default 24 \
    && fnm use 24 \
    && node24_root="$(dirname "$(dirname "$(readlink -f "$(command -v node)")")")" \
    && test -x "${node24_root}/bin/node" \
    && ln -sfn "${node24_root}" /azp/externals/node24

RUN echo 'Tool                     Version' \
    && echo '------------------------ ----------------------------------------' \
    && awk -F '\t' '{ printf "%-24s %s\n", $1, $2 }' "${TOOL_VERSIONS_FILE}"

ENTRYPOINT ./start.sh
