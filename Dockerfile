FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
ENV TARGETARCH="linux-musl-x64"
ENV VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"
ARG BUILD_AZP_TOKEN
ARG BUILD_AZP_URL
RUN apk update \
    && apk upgrade \
    && apk add bash curl git icu-libs jq gcc musl-dev python3-dev libffi-dev openssl-dev cargo make py3-pip nodejs npm

WORKDIR /azp/

COPY ./install.sh /azp/
COPY ./start.sh /azp/

RUN chmod +x ./install.sh \
    && chmod +x ./start.sh \
    && adduser -D agent \
    && chown agent ./ 

# Install Azure CLI
RUN pip install --upgrade pip \
    && pip  --no-cache-dir install azure-cli \
    && az bicep upgrade \
    && az version -o table

# Install .NET
RUN curl -Lsfo "dotnet-install.sh" https://dot.net/v1/dotnet-install.sh \
    && chmod +x "dotnet-install.sh" \
    && ./dotnet-install.sh --channel 6.0 --install-dir /usr/share/dotnet \
    && ./dotnet-install.sh --channel 7.0 --install-dir /usr/share/dotnet \
    && ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet


USER agent

# Install DevOps Agent
RUN (export AZP_TOKEN=${BUILD_AZP_TOKEN};export AZP_URL=${BUILD_AZP_URL}; ./install.sh) 

# Prime .NET
ENV NUGET_PACKAGES="/azp/nuget/NUGET_PACKAGES"
ENV NUGET_HTTP_CACHE_PATH="/azp/nuget/NUGET_HTTP_CACHE_PATH"
RUN mkdir /azp/nuget \
    && mkdir /azp/nuget/NUGET_PACKAGES \
    && mkdir /azp/nuget/NUGET_HTTP_CACHE_PATH \
    && mkdir prime \
    && cd prime \
    && dotnet new globaljson --force --sdk-version 8.0.0 --roll-forward latestFeature \
    && dotnet --version \
    && dotnet --info \
    && dotnet new console -n testconsole --framework net8.0 \
    && dotnet build testconsole \
    && rm -rf testconsole \
    && rm global.json \
    && dotnet new globaljson --sdk-version 7.0.0 --roll-forward latestFeature \
    && dotnet --version \
    && dotnet --info \
    && dotnet new console -n testconsole --framework net7.0 \
    && dotnet build testconsole \
    && rm -rf testconsole \
    && rm global.json \
    && dotnet new globaljson --sdk-version 6.0.0 --roll-forward latestFeature \
    && dotnet --version \
    && dotnet --info \
    && dotnet new console -n testconsole --framework net6.0 \
    && dotnet build testconsole \
    && rm -rf testconsole \
    && cd .. \
    && rm -rf prime 

ENTRYPOINT ./start.sh