#!/usr/share/powershell/pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 7.3
$env:Verify_GitHubSponsorAccount='wcomab'
[string[]] $netversions = @(
    '8.0',
    '9.0',
    '10.0',
    '11.0'
    )

[string[]] $templates = @(
        'console',
        'web',
        'classlib',
        'mstest',
        'xunit',
        'xunit3',
        'nunit'
        )

[long] $ResultCode = 0

function Write-Net11GlobalJson
{
    param([Parameter(Mandatory)][string] $Path)

    @'
{
  "sdk": {
    "version": "11.0.0",
    "rollForward": "latestFeature",
    "allowPrerelease": true
  }
}
'@ | Set-Content -Path $Path -Encoding utf8NoBOM
}

$netversions `
 | ForEach-Object {
    [string] $netversion    =$_
    [string] $framework     ="net$netversion"
    [string] $sdkVersion    ="$netversion.0"
    Push-Location
    New-Item -Path $framework -ItemType Directory `
        | Set-Location

    if ($netversion -eq '11.0')
    {
        Write-Net11GlobalJson -Path './global.json'
    }
    else
    {
        dotnet new globaljson --force --sdk-version $sdkVersion --roll-forward latestFeature
    }
    dotnet --version
    dotnet --info

    $templates `
        | ForEach-Object {
            [string] $template = $_
            [string] $project = "test$template"
            Push-Location
            New-Item -Path $template -ItemType Directory `
             | Set-Location

            if ($template -eq 'xunit3' -and $netversion -eq '11.0')
            {
                # xunit.v3.templates has no net11.0 choice yet; retarget after create
                dotnet new $template -n $project
                $ResultCode+=$LASTEXITCODE
                Write-Net11GlobalJson -Path '../global.json'
                $csproj = Join-Path $project "$project.csproj"
                if (Test-Path -Path $csproj)
                {
                    (Get-Content -Raw $csproj) -replace '<TargetFramework>net\d+\.\d+</TargetFramework>', "<TargetFramework>$framework</TargetFramework>" |
                        Set-Content -Path $csproj
                }
            }
            else
            {
                dotnet new $template -n $project --framework $framework
                $ResultCode+=$LASTEXITCODE
            }

            if ($template -ne 'mstest' -or ($netversion -ne '9.0' -and $netversion -ne '10.0' -and $netversion -ne '11.0'))
            {
                if ($netversion -ne '10.0' -and $netversion -ne '11.0')
                {
                    dotnet outdated -u $project
                    $ResultCode+=$LASTEXITCODE

                    switch($template)
                    {
                        'console' {
                        }
                        'web' {
                        }
                        'classlib' {
                        }
                        'xunit3' {
                            dotnet add $project package 'Verify.XunitV3'
                            $ResultCode+=$LASTEXITCODE
                        }
                        Default {
                            dotnet add $project package "Verify.$template"
                            $ResultCode+=$LASTEXITCODE
                        }
                    }
                }
            }

            dotnet build $project
            $ResultCode+=$LASTEXITCODE

            Pop-Location
            Remove-Item -Recurse -Force $template
        }
    Pop-Location
    Remove-Item -Recurse -Force $framework
 }

 exit $ResultCode
