$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.ps1', '.psm1'
# Remove Module if exists
if ((Get-Module ManagePSProject).Name -eq "ManagePSProject") {
    Remove-Module ManagePSProject
}
Import-Module "$here\$sut"


Describe "ManagePSProject" {
    
    $pestertestTitle = "pestertest"
    $PesterTestPath = "$here\$pestertestTitle"
    Remove-Item $PesterTestPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item $PesterTestPath -ItemType Directory -Force | Out-Null
    Set-Location $PesterTestPath

    Context "Test -Init Flag" {
        ManagePSProject -Init -Test

        It "config folder should exist" {
            (Test-Path "$PesterTestPath\config") | should be $true
        }
        It "installers folder should exist" {
            (Test-Path "$PesterTestPath\installers") | should be $true
        }
        It "utils folder should exist" {
            (Test-Path "$PesterTestPath\utils") | should be $true
        }
        It ".gitignore file should exist" {
            (Test-Path "$PesterTestPath\.gitignore") | should be $true
        }
        It "$pestertestTitle.ps1 main script should exist" {
            (Test-Path "$PesterTestPath\$pestertestTitle.ps1") | should be $true
        }
        It "projectInfo.json file should exist" {
            (Test-Path "$PesterTestPath\projectInfo.json") | should be $true
        }
        It "README.md file should exist" {
            (Test-Path "$PesterTestPath\README.md") | should be $true
        }
    }    
    Context "Test -SemVer flag" {
        $SVer = ManagePSProject -SemVer 
        It "testutil.ps1 file should exist" {
            ($SVer -eq "0.0.0") | should be $true
        }
    }    
    Context "Test -GetInfo flag" {
        $ver = (ManagePSProject -GetInfo).version
        It "projectInfo 'Version' should be '0.0.0'" {
            ($ver -eq "0.0.0") | should be $true
        }
    }
    Context "Test -SetInfo flag" {
        $ver = (ManagePSProject -SetInfo -Test).version
        It "projectInfo 'Version' should be '7.1.1'" {
            ($ver -eq "7.1.1") | should be $true
        }
    }
    Context "Test -Reset flag" {
        ManagePSProject -Reset -Test
        $ver = (Get-Content -Raw -Path ".\projectInfo.json" | ConvertFrom-Json).version
        It "projectInfo 'Version' should be '0.0.0'" {
            ($ver -eq "0.0.0") | should be $true
        }
    }
    Context "Test -GenUTIL flag" {
        ManagePSProject -GenUTIL -Test
        It "testutil.ps1 file should exist" {
            (Test-Path "$PesterTestPath\utils\testutil.ps1") | should be $true
        }
    }
    Context "Test -Build flag" {
        ManagePSProject -Build -Test
        It "$pestertestTitle.zip file should exist" {
            (Test-Path "$PesterTestPath\releases\v0.0.0\$pestertestTitle.zip") | should be $true
        }
    }
    Context "Test -Flush flag" {
        ManagePSProject -Flush -Test
        It "releases directory should not exist" {
            (Test-Path "$PesterTestPath\releases") | should be $false
        }
    }
    Context "Test -Publish flag" {
        ManagePSProject -Publish -Test
        It ".git directory should exist" {
            (Test-Path "$PesterTestPath\.git") | should be $true
        }
        # It "Test that remote repository was pushed to." {
        #     git remote show origin
        #     (git pull origin master) -eq "Already up to date." | should be $true
        # }
    }
    
    Set-Location $here
    Remove-Item $PesterTestPath -Recurse -Force | Out-Null
}
