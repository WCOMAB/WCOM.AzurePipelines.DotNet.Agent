#!/bin/bash
UBUNTU_VERSION="$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)"
if ! [[ "18.04 20.04 22.04 24.04 26.04" == *"${UBUNTU_VERSION}"* ]];
then
    echo "Ubuntu ${UBUNTU_VERSION} is not currently supported.";
    exit;
fi

# Download the package to configure the Microsoft repo
curl -sSL -O https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb
# Install the package
dpkg -i packages-microsoft-prod.deb
# Delete the file
rm packages-microsoft-prod.deb

# Install the driver
apt-get update
ACCEPT_EULA=Y apt-get install -y msodbcsql18
# optional: for bcp and sqlcmd
ACCEPT_EULA=Y apt-get install -y mssql-tools18
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
# optional: for unixODBC development headers
apt-get install -y unixodbc-dev
