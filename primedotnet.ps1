#!/usr/share/powershell/pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 7.3
$env:Verify_GitHubSponsorAccount='wcomab'
[string[]] $netversions = @(
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
            if ($LASTEXITCODE -ne 0)
            {
                # Template doesn't support framework yet, create with default and retarget
                dotnet new $template -n $project
                $ResultCode+=$LASTEXITCODE
                [string] $csproj = "$project/$project.csproj"
                (Get-Content -Raw $csproj) `
                    -replace '<TargetFrameworks?>[^<]*</TargetFrameworks?>', "<TargetFramework>$framework</TargetFramework>" `
                    | Set-Content -NoNewline $csproj
            }

            if ($template -ne 'mstest')
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

            dotnet build $project
            $ResultCode+=$LASTEXITCODE

            Pop-Location
            Remove-Item -Recurse -Force $template
        }
    Pop-Location
    Remove-Item -Recurse -Force $framework
 }

 exit $ResultCode
