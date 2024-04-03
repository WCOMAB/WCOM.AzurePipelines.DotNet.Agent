# Azure CLI not compatible with alpine3.19
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine3.18 AS build
ARG BUILD_AZP_TOKEN
ARG BUILD_AZP_URL
ARG BUILD_AZP_VERSION=1.0.0.0

ENV TARGETARCH="linux-musl-x64"
ENV VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"
ENV BUILD_AZP_VERSION="${BUILD_AZP_VERSION}"


RUN apk update \
    && apk upgrade \
    && apk add bash curl git icu-libs jq gcc musl-dev python3-dev libffi-dev openssl-dev libssl-dev cargo make py3-pip nodejs npm zip gnupg libintl


# Install Azure CLI
RUN pip install --upgrade pip \
    && pip  --no-cache-dir install azure-cli \
    && az bicep upgrade \
    && az version -o table

WORKDIR /azp/

COPY ./install.sh /azp/
COPY ./start.sh /azp/
COPY ./primedotnet.ps1 /azp/
COPY ./installsqltools.sh /azp/

RUN chmod +x ./install.sh \
    && chmod +x ./start.sh \
    && chmod +x ./primedotnet.ps1 \
    && chmod +x installsqltools.sh \
    && adduser -D agent \
    && chown -R agent ./

# Install MS SQL Tools / Drivers
ENV PATH="${PATH}:/opt/mssql-tools18/bin/"
RUN ./installsqltools.sh \
    && sqlcmd "-?"

USER agent

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
    && ./dotnet-install.sh --channel 8.0 --install-dir /azp/tools/dotnet

# Install DevOps Agent
RUN export AZP_TOKEN=${BUILD_AZP_TOKEN} \
    && export AZP_URL=${BUILD_AZP_URL} \
    && ./install.sh

# Configure Node, Install Azurite & Renovate
ENV PATH="${PATH}:/home/agent/.npm-global/bin"
RUN mkdir /home/agent/.npm-global \
    && npm config set prefix '/home/agent/.npm-global' \
    && npm install -g azurite \
    && npm install -g renovate

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
RUN ./primedotnet.ps1

ENTRYPOINT ./start.sh
