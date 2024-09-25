#!/usr/share/powershell/pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 7.3

[string[]] $netversions = @(
    '6.0',
    '7.0',
    '8.0',
    '9.0'
    )

[string[]] $templates = @(
        'console',
        'web',
        'classlib',
        'mstest',
        'xunit',
        'nunit'
        )

[long] $ResultCode = 0


$netversions `
 | ForEach-Object {
    [string] $netversion    =$_
    [string] $framework     ="net$netversion"
    [string] $sdkVersion    ="$netversion.0"
    Push-Location
    New-Item -Path $framework -ItemType Directory `
        | Set-Location

    dotnet new globaljson --force --sdk-version $sdkVersion --roll-forward latestFeature
    dotnet --version
    dotnet --info

    $templates `
        | ForEach-Object {
            [string] $template = $_
            [string] $project = "test$template"
            Push-Location
            New-Item -Path $template -ItemType Directory `
             | Set-Location

            dotnet new $template -n $project --framework $framework
            $ResultCode+=$LASTEXITCODE

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
                Default {
                    dotnet add $project package "Verify.$template"
                    $ResultCode+=$LASTEXITCODE
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