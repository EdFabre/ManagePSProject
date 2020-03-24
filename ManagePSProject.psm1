<#
.NOTES
    Name: ManagePSProject.psm1
    Author: Edge Fabre
    Date created: 07-22-2019
.SYNOPSIS
    Used to manage the project through it's lifecycle
.DESCRIPTION
    Utilizes variable modules to package, maintain and share this project.
.PARAMETER Build
    When set to true, this flag packs the project into a zip saved to 'releases'.
.PARAMETER Reset
    When set to true, this flag updates the version number of project to 0 and prompts for new info. This does not alter existing files/folders
.PARAMETER Publish
    When set, this flag will push the git repo to remote repo
.PARAMETER Flush
    When set, this flag clears old releases from the 'releases' folder. Bear in mind, when using this flag, project will not pack.
.PARAMETER Init
    When set, this flag prompts the user for project details and updates the project info file and builds project environment. Bear in mind, when using this flag, project will not pack.
.PARAMETER GetInfo
    When set, this flag returns information about this project. Bear in mind, when using this flag, project will not pack.
.PARAMETER SetInfo
    When set, this flag prompts user for information about this project. Bear in mind, when using this flag, project will not pack.
.PARAMETER SemVer
    When set, this flag returns the semantic MAJOR.MINOR.PATCH version of the project. Bear in mind, when using this flag, project will not pack.
.PARAMETER Develop
    When set, this flag monitors project for changes in files and restarts main application. Bear in mind, when using this flag, project will not pack.
.PARAMETER GenUTIL
    When set, this flag generates Utility for Project saved to utils folder.
.PARAMETER AddDeps
    When set, this flag adds a powershell github repo as a dependency.
.PARAMETER ListDeps
    When set, this flag prints the dependencies added to the project.
.INPUTS
    Optional Switches
.OUTPUTS
    Varies based on Inputs
.EXAMPLE
    ManagePSProject -Build # Packages project and increments version number
    ManagePSProject -Reset # Resets project's info
    ManagePSProject -Publish "Sample Commit Message" # Pushes this repository to remote git repo
    ManagePSProject -Flush # Clears 'releases' folder
    ManagePSProject -Init # Initializes projectinfo config file for the project and builds project environment
    ManagePSProject -GetInfo # Returns the current information of project
    ManagePSProject -SetInfo # Sets information of project
    ManagePSProject -SemVer # Returns the current Semantic Version
    ManagePSProject -Develop "Arguments for main script" # Runs application in development mode
    ManagePSProject -GenUTIL # Generates Utility for Project saved to utils folder"
    ManagePSProject -AddDeps "https://github.com/random/repo" # Adds a powershell github repo to script session, can add several by using space delimiter
    ManagePSProject -ListDeps # Displays the dependencies of this project
#>

function ManagePSProject {
    # Receives script parameters
    param (
        [Parameter(Mandatory = $false)]    
        [Switch]$Build,
        [Parameter(Mandatory = $false)]    
        [Switch]$Reset,
        [Parameter(Mandatory = $false)]    
        [Switch]$Publish,    
        [Parameter(Position = 0, Mandatory = $false)]    
        [String]$ARGorSTRING,
        [Parameter(Mandatory = $false)]    
        [Switch]$Flush,
        [Parameter(Mandatory = $false)]    
        [Switch]$Init,
        [Parameter(Mandatory = $false)]    
        [Switch]$Silent,
        [Parameter(Mandatory = $false)]    
        [Switch]$Test,
        [Parameter(Mandatory = $false)]    
        [Switch]$GetInfo,
        [Parameter(Mandatory = $false)]    
        [Switch]$SetInfo,
        [Parameter(Mandatory = $false)]    
        [Switch]$SemVer,
        [Parameter(Mandatory = $false)]    
        [Switch]$Develop,
        [Parameter(Mandatory = $false)]    
        [Switch]$GenUTIL,
        [Parameter(Mandatory = $false)]    
        [Switch]$AddDeps,
        [Parameter(Mandatory = $false)]    
        [Switch]$ListDeps,
        [Parameter(Mandatory = $false)]    
        [Switch]$LoadDeps,
        [Parameter(Mandatory = $false)]    
        [Switch]$GetGitBranchURL
    )

    # Project path variables
    $scriptPath = (Get-Location).Path
    $projectDirName = Split-Path ($scriptPath) -Leaf
    $releasesPath = "$scriptPath\releases"
    $configPath = "$scriptPath\config"
    $installersPath = "$scriptPath\installers"
    $utilsPath = "$scriptPath\utils"
    $projectInfoPath = "$scriptPath\projectInfo.json"
    
    function isURIWeb($address) {
        $uri = $address -as [System.URI]
        $null -ne $uri.AbsoluteURI -and $uri.Scheme -match '[http|https]'
    }

    function validateGithubURL {
        param (
            [Parameter(Position = 0, Mandatory = $true)]
            [String]$githubURL
        )

        if (isURIWeb $githubURL) {
            if ($githubURL -like "*github.*") {
                return $true
            }
            else {
                return $false
            }
        }
        else {
            return $false
        }
    }

    function GetGithubDefaultBranchURL {
        param (
            [Parameter(Position = 0, Mandatory = $true)] 
            $url
        )
        if ((validateGithubURL($url)) -ne $true) {
            return $null
        } 

        try {
            $Response = Invoke-WebRequest -URI "$url/branches" -UseBasicParsing
            $StatusCode = $Response.StatusCode
            if ($StatusCode -eq 200) {
                $HTML = New-Object -Com "HTMLFile"
                $HTML.IHTMLDocument2_write($Response.Content)
                $branches = ($HTML.all.tags("a") | Where-Object { $_.className -match 'branch-name' })
                
                if ($branches -is [System.Array]) {
                    return "$url/archive/$($branches[0].innerText).zip"
                }
                else {
                    return "$url/archive/$($branches.innerText).zip"
                }
            }
            else {
                # Write-Host "Unable to connect: $StatusCode"
                return $null
            }
        }
        catch {
            # Write-Host "Unable to connect, exception thrown, check url"
            return $null
        }
    }

    function AddRepos {
        param (
            [Parameter(Mandatory = $true)]    
            [String]$Repos
        )
        $projectInfo = GetProjectInfo
        $dependencies = $projectInfo.dependencies
        $SplitRepos = $Repos.Split(" ")

        foreach ($repo in $SplitRepos) {
            $zippedGitRepoURL = (GetGithubDefaultBranchURL $repo)
            if ($null -ne $zippedGitRepoURL) {
                $depName = $repo.Split("/")
                $depName = ($depName[($depName.Length) - 1]).ToLower()
                $dependencies = addPSObjectProp $dependencies $depName $repo
            }
            else {
                Write-Host "No repo found at url $repo !"
            }
        }
        $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
        ListDependencies
    }

    function addPSObjectProp {
        param (
            [Parameter(Position = 0, Mandatory = $true)]
            [Object]$TempPSOject,
            [Parameter(Position = 1, Mandatory = $true)]
            [String]$TempPSOjectName,
            [Parameter(Position = 2, Mandatory = $true)]
            [String]$TempPSOjectValue
        )
        $TempPSOject | Add-Member -MemberType NoteProperty -Name $TempPSOjectName -Value $TempPSOjectValue -Force
        return $TempPSOject
    }

    function LoadDependencies {  
        $projectInfo = GetProjectInfo
        $dependencies = $projectInfo.dependencies
    
        
        # Used to store dependency disk locations
        $RepoInstallPackages = New-Object -TypeName psobject
    
        $dependencies | Get-Member -MemberType NoteProperty | ForEach-Object {
            $key = $_.Name
            $value = GetGithubDefaultBranchURL "$($dependencies."$key")"
            
            LoadRepo -InstallPackagesObj $RepoInstallPackages -RepoName $key -RepoURL $value
        }  
        return $RepoInstallPackages
    }

    function LoadRepo {
        param (
            [Parameter(Mandatory = $true)]    
            [String]$RepoName,
            [Parameter(Mandatory = $true)]    
            [String]$RepoURL,
            [Parameter(Mandatory = $true)]    
            [Object]$InstallPackagesObj
        )
    
        $zippedGitRepo = "$utilsPath\$RepoName.zip"
        # Update old zipped repo
        if (Test-Path $zippedGitRepo) {
            Remove-Item -Recurse -Force -Path $zippedGitRepo -ErrorAction SilentlyContinue | Out-Null
        }
        Invoke-WebRequest -Uri $RepoURL -OutFile $zippedGitRepo
    
        $utilModulePath = "$utilsPath\$($RepoName)_000"
        if (Test-Path $utilModulePath) {
            Remove-Item -Recurse -Force -Path $utilModulePath -ErrorAction SilentlyContinue | Out-Null
        }
        Expand-Archive -Path $zippedGitRepo -DestinationPath "$utilModulePath" | Out-Null
    
        Get-ChildItem $utilModulePath | ForEach-Object {
            $ModuleName = ($_.BaseName).Split('-')
    
            if ($ModuleName.length -eq 2) {
                $ModuleName = $ModuleName[0]
                $modulePath = "$utilsPath\$ModuleName"
    
                if (Test-Path $modulePath) {
                    Remove-Item -Recurse -Force -Path $modulePath -ErrorAction SilentlyContinue | Out-Null
                }
                $drillOneUtilModPath = "$utilModulePath\$($_.BaseName)"
                if (Test-Path $drillOneUtilModPath) {
                    Copy-Item -Path "$drillOneUtilModPath" -Destination $modulePath -Recurse -Force
                } 
                $InstallPackagesObj | Add-Member -MemberType NoteProperty -Name $ModuleName -Value @($modulePath, $utilModulePath, $zippedGitRepo, $RepoURL) -Force
            }
        }
    }

    function ListDependencies {
        
        $projectInfo = GetProjectInfo
        $dependencies = $projectInfo.dependencies
        $dependencies | Get-Member -MemberType NoteProperty | ForEach-Object {
            $key = $_.Name
            [PSCustomObject]@{Dependency = $key; Repo = $dependencies."$key" }
        }
    }

    function FlushProjectReleases {
        if (Test-Path $releasesPath) {
            Remove-Item -Path "$releasesPath" -Recurse -Force
            if ((Test-Path $releasesPath) -eq $false) {
                if ($Test -eq $false) {
                    Write-Host "Releases have been flushed!"                    
                }
            }
        }
        else {
            if ($Test -eq $false) {
                Write-Host "There are no releases, or path DNE."
            }
        }
    }

    function CleanupEnvironment {
        $projectInfo = GetProjectInfo
        if ($Test -eq $false) {
            Write-Host "$($projectInfo.main)"                    
        }
        Remove-Item -Path "$releasesPath" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$configPath" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$installersPath" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$utilsPath" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$scriptPath\.git" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$scriptPath\.gitignore" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$($projectInfo.main)" -Force 
        Remove-Item -Path "$scriptPath\README.md" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$projectInfoPath" -Force -ErrorAction SilentlyContinue
        if ($Test -eq $false) {
            Write-Host "Environment has been purged."
        }
    }

    function PublishProject {
        param (
            [Parameter(Mandatory = $false)]    
            [String]$MSG,
            [Parameter(Mandatory = $false)]    
            [Switch]$Release
        )
    
        $projectInfo = GetProjectInfo
        $gitRepository = [string]$projectInfo.gitRepo

        if ($Test) {
            git init
            $gitRepository = "https://github.com/EdFabre/ManagePSProjectTEST.git"
            git remote add origin $gitRepository *> $null
            git fetch --all *> $null
            git reset --hard origin/master *> $null
            git pull origin master *> $null
        }
        try {
            git | Out-Null
            if (Test-Path -Path "$scriptPath\.git") {

                $x = git remote -v 
                if ($null -ne $x) {
                    if ([string]::IsNullOrWhiteSpace($MSG)) {
                        if ($Test) {
                            git add . *> $null
                            git commit -m "Automatically pushed!" *> $null 
                            if ($Release) {
                                $tempVer = SemVer
                                git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                git push -u origin master --tags *> $null
                            }
                            else {
                                git push -u origin master *> $null
                            }
                        }
                        else {
                            git add . 
                            git commit -m "Automatically pushed!" 
                            if ($Release) {
                                $tempVer = SemVer
                                git tag -a $tempVer -m "Releasing version $tempVer"
                                git push -u origin master --tags
                            }
                            else {
                                git push -u origin master
                            }
                        }
                    }
                    else {
                        if ($Test) {
                            git add . *> $null
                            git commit -m $MSG *> $null 
                            if ($Release) {
                                $tempVer = SemVer
                                git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                git push -u origin master --tags *> $null
                            }
                            else {
                                git push -u origin master *> $null
                            }
                        }
                        else {
                            git add . 
                            git commit -m $MSG 
                            if ($Release) {
                                $tempVer = SemVer
                                git tag -a $tempVer -m "Releasing version $tempVer"
                                git push -u origin master --tags
                            }
                            else {
                                git push -u origin master
                            }
                        }
                    }
                }
                else {
                    if ([string]::IsNullOrWhiteSpace($gitRepository)) {
                        $setRemote = Read-Host -Prompt  "Git Remote is not Set! Would you like to set one now? (Y)"
                        if (([string]::IsNullOrWhiteSpace($setRemote)) -Or ($setRemote -eq "Y")) {
                            $gitRepository = Read-Host -Prompt  "What is the remote URL?"
                            if ([string]::IsNullOrWhiteSpace($gitRepository)) {
                                if ($Test -eq $false) {
                                    Write-Host "No remote URL has been set."
                                }
                                
                            }
                            elseif ((isURIWeb($gitRepository)) -eq $false) {
                                if ($Test -eq $false) {
                                    Write-Host "The value provided is not a valid URL."                    
                                }
                            }
                            else {
                                $projectInfo.gitRepo = $gitRepository

                                if ([string]::IsNullOrWhiteSpace($MSG)) {
                                    if ($Test) {
                                        git add . *> $null 
                                        git commit -m "Automatically pushed!" *> $null
                                        git remote add origin "$gitRepository" *> $null 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                            git push -u origin master --tags *> $null
                                        }
                                        else {
                                            git push -u origin master *> $null
                                        }
                                    }
                                    else {
                                        git add . 
                                        git commit -m "Automatically pushed!"
                                        git remote add origin "$gitRepository" 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer"
                                            git push -u origin master --tags
                                        }
                                        else {
                                            git push -u origin master
                                        }
                                    }
                                }
                                else {
                                    if ($Test) {
                                        git add . *> $null 
                                        git commit -m $MSG *> $null 
                                        git remote add origin "$gitRepository" *> $null  
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer" *> $null 
                                            git push -u origin master --tags *> $null 
                                        }
                                        else {
                                            git push -u origin master *> $null 
                                        }
                                    }
                                    else {
                                        git add . 
                                        git commit -m $MSG
                                        git remote add origin "$gitRepository" 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer"
                                            git push -u origin master --tags
                                        }
                                        else {
                                            git push -u origin master
                                        }
                                    }
                                }

                                # Convert Project Info to JSON Object file
                                $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
                            }
                        }
                    }
                    else {
                        if ([string]::IsNullOrWhiteSpace($MSG)) {
                            if ($Test) {
                                git add . *> $null 
                                git commit -m "Automatically pushed!" *> $null
                                git remote add origin "$gitRepository" *> $null 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                    git push -u origin master --tags *> $null
                                }
                                else {
                                    git push -u origin master *> $null
                                }
                            }
                            else {
                                git add . 
                                git commit -m "Automatically pushed!"
                                git remote add origin "$gitRepository" 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer"
                                    git push -u origin master --tags
                                }
                                else {
                                    git push -u origin master
                                }
                            }
                        }
                        else {
                            if ($Test) {
                                git add . *> $null 
                                git commit -m $MSG *> $null
                                git remote add origin "$gitRepository" *> $null 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                    git push -u origin master --tags *> $null
                                }
                                else {
                                    git push -u origin master *> $null
                                }
                            }
                            else {
                                git add . 
                                git commit -m $MSG
                                git remote add origin "$gitRepository" 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer"
                                    git push -u origin master --tags
                                }
                                else {
                                    git push -u origin master
                                }
                            }
                        }
                    }
                }
            }
            else {
                $doNow = Read-Host "Git repository not initialized. Would you like to initialize it now? (Y)"
                if (([string]::IsNullOrWhiteSpace($doNow)) -OR ($doNow -eq "Y")) {
                    if ($Test -eq $false) {
                        Write-Host "Initializing Git Repository"                    
                    }
                    git init
                    if ([string]::IsNullOrWhiteSpace($gitRepository)) {
                        $setRemote = Read-Host -Prompt  "Git Remote is not Set! Would you like to set one now? (Y)"
                        if (([string]::IsNullOrWhiteSpace($setRemote)) -Or ($setRemote -eq "Y")) {
                            $gitRepository = Read-Host -Prompt  "What is the remote URL?"
                            if ([string]::IsNullOrWhiteSpace($gitRepository)) {
                                if ($Test -eq $false) {
                                    Write-Host "No remote URL has been set."                    
                                }
                            }
                            elseif ((isURIWeb($gitRepository)) -eq $false) {
                                if ($Test -eq $false) {
                                    Write-Host "The value provided is not a valid URL."                    
                                }
                            }
                            else {
                                $projectInfo.gitRepo = $gitRepository

                                if ([string]::IsNullOrWhiteSpace($MSG)) {
                                    if ($Test) {
                                        git add . *> $null 
                                        git commit -m "Automatically pushed!" *> $null
                                        git remote add origin "$gitRepository" *> $null 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                            git push -u origin master --tags *> $null
                                        }
                                        else {
                                            git push -u origin master *> $null
                                        }
                                    }
                                    else {
                                        git add . 
                                        git commit -m "Automatically pushed!"
                                        git remote add origin "$gitRepository" 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer"
                                            git push -u origin master --tags
                                        }
                                        else {
                                            git push -u origin master
                                        }
                                    }
                                }
                                else {
                                    if ($Test) {
                                        git add . *> $null 
                                        git commit -m $MSG *> $null 
                                        git remote add origin "$gitRepository" *> $null  
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer" *> $null 
                                            git push -u origin master --tags *> $null 
                                        }
                                        else {
                                            git push -u origin master *> $null 
                                        }
                                    }
                                    else {
                                        git add . 
                                        git commit -m $MSG
                                        git remote add origin "$gitRepository" 
                                        if ($Release) {
                                            $tempVer = SemVer
                                            git tag -a $tempVer -m "Releasing version $tempVer"
                                            git push -u origin master --tags
                                        }
                                        else {
                                            git push -u origin master
                                        }
                                    }
                                }

                                # Convert Project Info to JSON Object file
                                $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
                            }
                        }                    
                    }
                    else {
                        if ([string]::IsNullOrWhiteSpace($MSG)) {
                            if ($Test) {
                                git add . *> $null 
                                git commit -m "Automatically pushed!" *> $null 
                                git remote add origin "$gitRepository" *> $null 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                    git push -u origin master --tags *> $null
                                }
                                else {
                                    git push -u origin master *> $null
                                }
                            }
                            else {
                                git add . 
                                git commit -m "Automatically pushed!" 
                                git remote add origin "$gitRepository" 
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer"
                                    git push -u origin master --tags
                                }
                                else {
                                    git push -u origin master
                                }
                            }
                        }
                        else {
                            if ($Test) {
                                git add . *> $null
                                git commit -m $MSG *> $null
                                git remote add origin "$gitRepository"  *> $null
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer" *> $null
                                    git push -u origin master --tags *> $null
                                }
                                else {
                                    git push -u origin master *> $null
                                }
                            }
                            else {
                                git add . 
                                git commit -m $MSG 
                                git remote add origin "$gitRepository"  
                                if ($Release) {
                                    $tempVer = SemVer
                                    git tag -a $tempVer -m "Releasing version $tempVer" 
                                    git push -u origin master --tags 
                                }
                                else {
                                    git push -u origin master 
                                }
                            }
                        }
                    }
                }
            }
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            if ($Test -eq $false) {
                Write-Host "Git is not installed!"                    
            }
        }
    }

    function UpdateProjectVersion {
        param (
            [Parameter(Mandatory = $false)]    
            [Switch]$Minor,
            [Parameter(Mandatory = $false)]    
            [Switch]$Patch
        )

        # Get Project Info and convert to PS Object
        $projectInfo = GetProjectInfo

        if ($Reset) {
            $projectInfo = SetProjectInfo
        }
        else {
            if ($Minor) {
                $projectInfo.version = SemVer -Minor -Bump                        
            }
            elseif ($Patch) {
                $projectInfo.version = SemVer -Patch -Bump
            }
            else {
                $projectInfo.version = SemVer -Major -Bump            
            }
        }

        $projectInfo.title = $projectInfo.title -replace '\s', ''

        $projectInfo.PsObject.properties | ForEach-Object {
            $projectInfo | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
        }

        # Convert Project Info to JSON Object file
        $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
    }

    function GetProjectInfo {

        # Reads current projectInfo.json
        if (Test-Path -Path "$projectInfoPath") {
            $projectInfo = Get-Content -Raw -Path "$projectInfoPath" | ConvertFrom-Json 
            if ($GetInfo) {
                $projectInfo
                return
            }
            # Convert Project Info to JSON Object file
            $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
            return $projectInfo
        }
        else {
            $createNewInfo = Read-Host -Prompt "The project info has not yet been initialized. Would you like to initialize it now? (Y)"
            if (([string]::IsNullOrWhiteSpace($createNewInfo)) -Or ($createNewInfo -eq "Y")) {
                $projectInfo = SetProjectInfo
                if ($GetInfo) {
                    $projectInfo
                    $saveInfoJson = Read-Host -Prompt "Would you like to save this projects info? (Y)"
                    if (([string]::IsNullOrWhiteSpace($saveInfoJson)) -Or ($saveInfoJson -eq "Y")) {
                        # Convert Project Info to JSON Object file
                        $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
                    }
                    exit
                }
                # Convert Project Info to JSON Object file
                $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
                return $projectInfo
            }
        }
    }

    function SetProjectInfo {
        if (Test-Path -Path "$projectInfoPath") {
            $projectInfo = Get-Content -Raw -Path "$projectInfoPath" | ConvertFrom-Json 

            if ($Test -eq $false) {
                $tempProjectTitle = $projectInfo.title
                $projectInfo.title = Read-Host -Prompt "What is the title of this project? ($($projectInfo.title))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.title)) {
                    $projectInfo.title = $tempProjectTitle
                }    
            }
            

            if ($Test -eq $false) {
                $tempProjectDescription = $projectInfo.description
                $projectInfo.description = Read-Host -Prompt "What does this project do? ($($projectInfo.description))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.description)) {
                    $projectInfo.description = $tempProjectDescription
                }    
            }
            

            if ($Reset) {
                $projectInfo.version = "0.0.0"
            }
            else {
                if ($Test -eq $false) {
                    $tempProjectVersion = $projectInfo.version
                    $projectInfo.version = Read-Host -Prompt "What is the project's version? ($($projectInfo.version))"
                    if ([string]::IsNullOrWhiteSpace($projectInfo.version)) {
                        $projectInfo.version = $tempProjectVersion
                    }
                    else {
                        $projectInfo.version = Convert2SemVer $projectInfo.version
                    }
                }
                else {
                    $projectInfo.version = "7.1.1"
                }
            }

            if ($Test -eq $false) {
                $tempProjectAuthor = $projectInfo.author
                $projectInfo.author = Read-Host -Prompt "Who is the author of this project? ($($projectInfo.author))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.author)) {
                    $projectInfo.author = $tempProjectAuthor
                }    
            }
            

            if ($Test -eq $false) {
                $tempProjectGitRepo = $projectInfo.gitRepo
                $projectInfo.gitRepo = Read-Host -Prompt "What is the git remote repo? ($($projectInfo.gitRepo))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.gitRepo)) {
                    $projectInfo.gitRepo = $tempProjectGitRepo
                }    
            }
            

            if ($Test -eq $false) {
                $tempProjectMain = $projectInfo.main
                $projectInfo.main = Read-Host -Prompt "What is the path to main script 'i.e C:\Project\Main.ps1'? ($($projectInfo.main))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.main)) {
                    $projectInfo.main = $tempProjectMain
                }    
            }
            

            if ($Test -eq $false) {
                $tempProjectLicense = $projectInfo.license
                $projectInfo.license = Read-Host -Prompt "What is this project licensed under? ($($projectInfo.license))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.license)) {
                    $projectInfo.license = $tempProjectLicense
                }    
            }
            

            # Convert Project Info to JSON Object file
            $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
            return $projectInfo
        } 
        else {
            if ($Test -eq $false) {
                Write-Host "Project Info JSON DNE"                    
            }
            $projectInfo = @"
{
    "title":  "$projectDirName",
    "description":  null,
    "version":  "0.0.0",
    "author":  null,
    "gitRepo":  null,
    "main":  null,
    "license":  "NONE",
    "dependencies": {}
}
"@ | ConvertFrom-Json
            $projectInfo.main = "$scriptPath\$projectDirName.ps1"
            
            if ($Test -eq $false) {
                $tempProjectTitle = $projectInfo.title
                $projectInfo.title = Read-Host -Prompt "What is the title of this project? ($($projectInfo.title))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.title)) {
                    $projectInfo.title = $tempProjectTitle
                }
            }
            
            if ($Test -eq $false) {
                $tempProjectDescription = $projectInfo.description
                $projectInfo.description = Read-Host -Prompt "What does this project do? ($($projectInfo.description))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.description)) {
                    $projectInfo.description = $tempProjectDescription
                }
            }
            

            if ($Reset) {
                $projectInfo.version = "0.0.0"
            }
            else {
                if ($Test -eq $false) {
                    $tempProjectVersion = $projectInfo.version
                    $projectInfo.version = Read-Host -Prompt "What is the project's version? ($($projectInfo.version))"
                    if ([string]::IsNullOrWhiteSpace($projectInfo.version)) {
                        $projectInfo.version = $tempProjectVersion
                    }
                    else {
                        $projectInfo.version = Convert2SemVer $projectInfo.version
                    }
                }
            }
            if ($Test -eq $false) {
                $tempProjectAuthor = $projectInfo.author
                $projectInfo.author = Read-Host -Prompt "Who is the author of this project? ($($projectInfo.author))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.author)) {
                    $projectInfo.author = $tempProjectAuthor
                }
            }
            
            if ($Test -eq $false) {
                $tempProjectGitRepo = $projectInfo.gitRepo
                $projectInfo.gitRepo = Read-Host -Prompt "What is the git remote repo? ($($projectInfo.gitRepo))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.gitRepo)) {
                    $projectInfo.gitRepo = $tempProjectGitRepo
                }
            }
            
            if ($Test -eq $false) {
                $tempProjectMain = $projectInfo.main
                $projectInfo.main = Read-Host -Prompt "What is the path to main script 'i.e C:\Project\Main.ps1'? ($($projectInfo.main))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.main)) {
                    $projectInfo.main = $tempProjectMain
                }
            }
            
            if ($Test -eq $false) {
                $tempProjectLicense = $projectInfo.license
                $projectInfo.license = Read-Host -Prompt "What is this project licensed under? ($($projectInfo.license))"
                if ([string]::IsNullOrWhiteSpace($projectInfo.license)) {
                    $projectInfo.license = $tempProjectLicense
                }
            }
            

            # Convert Project Info to JSON Object file
            $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
            return $projectInfo
        }
    }

    function InitProjectInfo {
        $projectInfo = @"
{
    "title":  "$projectDirName",
    "description":  null,
    "version":  "0.0.0",
    "author":  null,
    "gitRepo":  null,
    "main":  null,
    "license":  "NONE",
    "dependencies": {}
}
"@ | ConvertFrom-Json

        $projectInfo.main = "$scriptPath\$projectDirName.ps1"
        if ($Test) {
            $Silent = $Test
        }
        # Cleanup old environment if project info exists
        if ($Silent -ne $true) {
            if (Test-Path "$projectInfoPath") {
                $cleanEnviro = Read-Host -Prompt "Would you like to purge existing project? (Y)"
                if (([string]::IsNullOrWhiteSpace($cleanEnviro)) -Or ($cleanEnviro -eq "Y")) {
                    CleanupEnvironment
                }
            }
            $projectInfo = SetProjectInfo
        }
        else {
            if (Test-Path "$projectInfoPath") {
                CleanupEnvironment
            }
        }

        # Clear-Host and build new environment
        if ($Test -eq $false) {
            Clear-Host
        } 

        # Convert Project Info to JSON Object file incase it isn't already
        $projectInfo | ConvertTo-Json -Depth 100 | Out-File "$projectInfoPath"
        GenerateBoiler
        return $projectInfo
    }

    function BuildProject {
        $projectInfo = GetProjectInfo
        if ($Test -eq $false) {
            Write-Host "Received Project info"                    
        }

        # Create releases
        $releaseVersion = SemVer
        $projectDirName = [string]$projectInfo.title

        Remove-Item -Path "C:\temp\v$releaseVersion\$projectDirName" -Recurse -Force -ErrorAction Ignore
        New-Item -Path "C:\temp\v$releaseVersion\" -Name "$projectDirName" -ItemType "directory" -Force | Out-Null
        New-Item -Path $releasesPath -Name "v$releaseVersion" -ItemType "directory" -Force | Out-Null

        # Package project into a zip
        Copy-Item "$scriptPath\*" -Destination "C:\temp\v$releaseVersion\$projectDirName" -Recurse -Force
        Remove-Item -Path "C:\temp\v$releaseVersion\$projectDirName\releases" -Recurse -ErrorAction Ignore
        Remove-Item -Path "C:\temp\v$releaseVersion\$projectDirName\.git" -Recurse -ErrorAction Ignore
        Compress-Archive -Path "C:\temp\v$releaseVersion\$projectDirName\*" -DestinationPath "$releasesPath\v$releaseVersion\$projectDirName" -Force
        Remove-Item -Path "C:\temp\v$releaseVersion" -Recurse -Force -ErrorAction Ignore
        if ($Test -eq $false) {
            Write-Host "Updating Project Info Version"                    
        }
        if ($Test -eq $false) {
            PublishProject "Publishing Build Version $releaseVersion" -Release
        }

        # Increment Project Version
        UpdateProjectVersion
    }

    function Convert2SemVer {
        param (
            [Parameter(Mandatory = $true)]
            [String]$version
        )
        $regVersion = $version.Split(".")
        
        # Converts a regular version to Semantic Version Array
        if ($regVersion.Length -eq 1) {
            $newSemVer = @()
            $newSemVer += ($regVersion[0] -as [int])
            $newSemVer += 0
            $newSemVer += 0
            $regVersion = $newSemVer -join "."
        }
        elseif ($regVersion.Length -eq 2) {
            $newSemVer = @()
            $newSemVer += ($regVersion[0] -as [int])
            $newSemVer += ($regVersion[1] -as [int])
            $newSemVer += 0
            $regVersion = $newSemVer -join "."
        }
        elseif ($regVersion.Length -eq 3) {
            $newSemVer = @()
            $newSemVer += ($regVersion[0] -as [int])
            $newSemVer += ($regVersion[1] -as [int])     
            $newSemVer += ($regVersion[2] -as [int])
    
            $regVersion = $newSemVer -join "."
        }
        return $regVersion 
    }

    function SemVer {
        param (
            [Parameter(Mandatory = $false)]    
            [Switch]$Major,
            [Parameter(Mandatory = $false)]    
            [Switch]$Minor,
            [Parameter(Mandatory = $false)]    
            [Switch]$Patch,
            [Parameter(Mandatory = $false)]    
            [Switch]$Reset,
            [Parameter(Mandatory = $false)]    
            [Switch]$Bump,
            [Parameter(Mandatory = $false)]    
            [Switch]$Drop
        )

        $projectInfo = GetProjectInfo

        $releaseVersion = [string]$projectInfo.version
        $semVer = $releaseVersion.Split(".")

        # Converts a regular version to Semantic Version Array
        if ($semVer.Length -ne 3) {
            $newSemVer = @()
            $newSemVer += ($semVer[0] -as [int])
            $newSemVer += 0
            $newSemVer += 0
            $semVer = $newSemVer
        }
        else {
            $newSemVer = @()
            $newSemVer += ($semVer[0] -as [int])
            $newSemVer += ($semVer[1] -as [int])
            $newSemVer += ($semVer[2] -as [int])        
            $semVer = $newSemVer
        }

    
        if ($Reset) {
            $semVer = @("0", "0", "0")
        }
        elseif ($Major) {
            if ($Bump) {
                $semVer[0] = $semVer[0] + 1
            }
            elseif ($Drop) {
                $semVer[0] = $semVer[0] - 1
            }
            else {
                if ($Test -eq $false) {
                    Write-Host "Project Patch Version: $($semVer[0])"                          
                }      
            }
        }
        elseif ($Minor) {
            if ($Bump) {
                $semVer[1] = $semVer[1] + 1
            }
            elseif ($Drop) {
                $semVer[1] = $semVer[1] - 1
            }
            else {
                if ($Test -eq $false) {
                    Write-Host "Project Patch Version: $($semVer[1])"                     
                }           
            }
        }
        elseif ($Patch) {
            if ($Bump) {
                $semVer[2] = $semVer[2] + 1
            }
            elseif ($Drop) {
                $semVer[2] = $semVer[2] - 1
            }
            else {
                if ($Test -eq $false) {
                    Write-Host "Project Patch Version: $($semVer[2])"                    
                }            
            }
        }
        else {
            return $semVer -join '.'
        }
        return $semVer -join '.'
    }

    function Develop {
        param (
            [Parameter(Position = 0, Mandatory = $false)]    
            [String]$scriptArgs = ""
        )

        # Invoke-Expression ((new-object net.webclient).DownloadString("http://bit.ly/Install-PsWatch"))
    
        # Import-Module pswatch
        # cls
    
        $MainProjectScript = "$((GetProjectInfo).main) $scriptArgs"
        Write-Host ""
        Write-Host "Starting Development Environment for script: $MainProjectScript"
        Write-Host ""

        Invoke-Expression "$MainProjectScript"
    
        # Start-Process -FilePath powershell -ArgumentList @("-NoExit", "'$MainProjectScript'")
        watch "." | ForEach-Object {
            Write-Host ""
            Write-Host "Changes detected, restarting Development Environment..."
            Write-Host "Starting Development Environment for script: $MainProjectScript"
            Write-Host ""

            Invoke-Expression "$MainProjectScript"
        }
    }

    function GenerateBoiler {
        <#
    .NOTES
        Name: GenerateBoiler
        Author: Edge Fabre
        Date created: 2/21/2020
    .SYNOPSIS
        Generates and creates the general boilerplate structure for standard project based on .\projectInfo.json
    .DESCRIPTION
        Generates and creates the general boilerplate structure for standard project based on .\projectInfo.json
    .INPUTS
        None
    .OUTPUTS
        Project structure is generated based on .\projectInfo.json
    .EXAMPLE
        GenerateBoiler
    #>
        if ($Test -eq $false) {
            Write-Host "Generating environment for new Managed Project."                    
        }
        New-Item -ItemType Directory -Force -Path $configPath | Out-Null
        Add-Content "$configPath\.keep" -Value "Placeholder to make sure directory structure is staged"
        New-Item -ItemType Directory -Force -Path $installersPath | Out-Null
        Add-Content "$installersPath\.keep" -Value "Placeholder to make sure directory structure is staged"
        New-Item -ItemType Directory -Force -Path $utilsPath | Out-Null
        Add-Content "$utilsPath\.keep" -Value "Placeholder to make sure directory structure is staged"
        Add-Content "$scriptPath\.gitignore" -Value "releases"

        GenerateMAIN
        GenerateREADME
        if ($Test -eq $false) {
            Write-Host "Loading Utility Modules."                    
        }
        GenerateUTILWriteLog
    }

    function GenerateMAIN {
        <#
    .NOTES
        Name: GenerateMAIN
        Author: Edge Fabre
        Date created: 2/21/2020
    .SYNOPSIS
        Writes the main project script to root
    .DESCRIPTION
        Writes the main project script to root
    .INPUTS
        None
    .OUTPUTS
        Powershell File saved to root directory
    .EXAMPLE
        GenerateMAIN
    #>
        $projectInfo = GetProjectInfo
        $projTitle = $projectInfo.title
        $projAuthor = $projectInfo.author
        $projDesc = $projectInfo.description
        if ($Test -eq $false) {
            Write-Host "Generating Main Script '$projTitle.ps1'."                    
        }

        $mainScript = @"
<#
.NOTES
    Name: $projTitle.ps1
    Author: $projAuthor
    Date created: $(Get-Date -Format "MM-dd-yyyy")
.SYNOPSIS
    $projDesc
.DESCRIPTION
    $projDesc
.PARAMETER ExampleParam
    [PLACEHOLDER]
.INPUTS
    [PLACEHOLDER]
.OUTPUTS
    [PLACEHOLDER]
.EXAMPLE
    [PLACEHOLDER]
#>

# Receives script parameters
param (
    [Parameter(Position = 0, Mandatory = `$false)]    
    [String]`$ExampleParam
)

# Project Path Variables
`$scriptPath = split-path -parent `$MyInvocation.MyCommand.Definition
`$configPath = "`$scriptPath\config"
`$installersPath = "`$scriptPath\installers"
`$utilsPath = "`$scriptPath\utils"
`$releasesPath = "`$scriptPath\releases"

# Imports Powershell Scripts listed in projectInfo.json and located in utils
function LoadAllDeps {
    function TestModActive {
        param (
            [Parameter(Mandatory = `$true)]
            [String]`$ModuleName,
            [Parameter(Mandatory = `$false)]
            [Switch]`$Silent
        )
        if (`$null -ne (Get-Module `$ModuleName)) {
            if (`$Silent -ne `$true) {
                Write-Host "Dependency: '`$ModuleName', Installed"
            }
            return `$true
        }
        else {
            if (`$Silent -ne `$true) {
                Write-Host "Dependency: '`$ModuleName', NOT installed"
            }
            return `$false
        }
    }

    `$depLoadResults = New-Object -TypeName psobject

    `$RepoInstallPackages = (ManagePSProject -LoadDeps)
    `$RepoInstallPackages | Get-Member -MemberType NoteProperty | ForEach-Object {
        `$key = `$_.Name
        `$modulePath = `$(`$RepoInstallPackages."`$key")[0]
        `$utilModulePath = `$(`$RepoInstallPackages."`$key")[1]
        `$zippedGitRepo = `$(`$RepoInstallPackages."`$key")[2]
        `$RepoURL = `$(`$RepoInstallPackages."`$key")[3]
        Import-Module `$modulePath -Force
        `$repoRes = if ((TestModActive `$key -Silent) -eq `$true) { "Installed" } else { "Not Installed" }
    
        `$depLoadResults | Add-Member -MemberType NoteProperty -Name `$key -Value @(`$repoRes, `$RepoURL) -Force
        Remove-Item -Recurse -Force -Path `$modulePath -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Recurse -Force -Path `$utilModulePath -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Recurse -Force -Path `$zippedGitRepo -ErrorAction SilentlyContinue | Out-Null
    }

    # Loads Local Scripts in 'utils' folder
    Get-ChildItem -Path `$utilsPath -Filter *.ps1 | ForEach-Object {
        Import-Module `$_.FullName -Force
        `$repoRes = if ((TestModActive `$_.BaseName -Silent) -eq `$true) { "Installed" } else { "Not Installed" }
    
        `$depLoadResults | Add-Member -MemberType NoteProperty -Name `$_.BaseName -Value @(`$repoRes, "`$(`$_.FullName)") -Force
    }

    `$formattedDepResults = @()
    `$depLoadResults | Get-Member -MemberType NoteProperty | ForEach-Object {
        `$key = `$_.Name
        `$formattedDepResults += [PSCustomObject]@{Dependency = `$key; Status = `$(`$depLoadResults."`$key")[0]; Source = `$(`$depLoadResults."`$key")[1] }
    }
    `$formattedDepResults | Format-Table -AutoSize
}

. LoadAllDeps 

Write-Log "Project Path Variables
Script Path: `$scriptPath
Config Path: `$configPath
Installer Path: `$installersPath
Util Path: `$utilsPath
Releases Path: `$releasesPath" "Debug"

### DO NOT ALTER ABOVE CODE ###
### Insert Code Logic Below ###

"@

        Remove-Item "$projTitle.ps1" -ErrorAction SilentlyContinue
        Add-Content "$projTitle.ps1" -Value $mainScript 
    }

    function GenerateREADME {
        <#
    .NOTES
        Name: GenerateREADME
        Author: Edge Fabre
        Date created: 2/21/2020
    .SYNOPSIS
        Writes a project README.md to project root
    .DESCRIPTION
        Writes a project README.md to project root
    .INPUTS
        None
    .OUTPUTS
        Markdown File saved to root directory
    .EXAMPLE
        GenerateREADME
    #>
        $projectInfo = GetProjectInfo
        $projTitle = $projectInfo.title
        $projDesc = $projectInfo.description
        if ($Test -eq $false) {
            Write-Host "Generating README 'README.ps1'."                    
        }

        $README_MD = @"
# $projTitle

$projDesc

## Getting Started

[Simple steps to get this program running]

## Maintaining Project

This project uses the ManagePSProject module which is used to maintain this project during it's lifecycle. See the below commands:

``````powershell
# Possible Commands
ManagePSProject [-Build] [-Reset] [-Publish] [-Flush] 
                [-Init] [-GetInfo] [-SetInfo] [-SemVer] 
                [-Develop] [-GenUTIL] [-AddDeps] [-ListDeps]

ManagePSProject -Build # Packages project and increments version number
ManagePSProject -Reset # Resets project's info
ManagePSProject -Publish `"Sample Commit Message`" # Pushes this repository to remote git repo
ManagePSProject -Flush # Clears 'releases' folder
ManagePSProject -Init # Initializes projectinfo config file for the project and builds project environment
ManagePSProject -GetInfo # Returns the current information of project
ManagePSProject -SetInfo # Sets information of project
ManagePSProject -SemVer # Returns the current Semantic Version
ManagePSProject -Develop `"Arguments for main script`" # Runs application in development mode
ManagePSProject -GenUTIL # Generates Utility for Project saved to utils folder
ManagePSProject -AddDeps "https://github.com/random/repo" # Adds a powershell github repo to script session, can add several by using space delimiter
ManagePSProject -ListDeps # Displays the dependencies of this project
``````

### Main Script

The main script, titled '[$projTitle.ps1]($projTitle.ps1)' example is where the project will be launched from.

### Sub Folders

The template contains included folders which each serve a purpose as defined below.

#### 'config' Folder

The 'config' folder should contain configuration files. For example a sample 'config' folder might contain config.cfg

#### 'installers' Folder

The 'installers' folder should contain installers and other executables. For example a sample 'installers' folder might contain Chrome.exe and Dropbox.exe

#### 'utils' Folder

The 'utils' folder should only contain scripts which can then be dot-sourced into the main powershell script.

#### 'releases' Folder

The 'releases' folder will contain the most recent build of the powershell deployment package. When changes are made to this repository, you can run the packaging utility to create a zip of the entire project.
"@

        Remove-Item "README.md" -ErrorAction SilentlyContinue
        Add-Content "README.md" -Value $README_MD 
    }

    # Generates Utility Scripts 
    function GenerateUTILWriteLog {
        <#
    .NOTES
        Name: GenerateUTILWriteLog
        Author: Edge Fabre
        Date created: 2/21/2020
    .SYNOPSIS
        Writes the Write-Log script to utils directory
    .DESCRIPTION
        Writes the Write-Log script to utils directory
    .INPUTS
        None
    .OUTPUTS
        Powershell File saved to utils directory
    .EXAMPLE
        GenerateUTILWriteLog
    #>
        $utilTitle = "Write-Log"
        $utilFILE = @"
`$projectDirName = Split-Path (Split-Path (Split-Path `$MyInvocation.MyCommand.Definition -Parent)) -Leaf
`$ScriptName = (Get-Item `$MyInvocation.PSCommandPath).Basename
`$ScriptLogsDirName = "ScriptLogs"


function Write-Log {
    <#
    .NOTES
        Name: Write-Log.ps1
        Author: Edge Fabre
        Date created: 02-12-2019
    .SYNOPSIS
        Writes a custom log object to disk
    .DESCRIPTION
        This is a custom commandlette which assists in writing detailed logs for
        a powershell project
    .PARAMETER ProjectName
        String which specifies the name of the project
    .INPUTS
        System.String. Single Word Project Name
    .OUTPUTS
        CSV. Writes a CSV File to the Temp folder
    .EXAMPLE
        // Writes to log file with the severity of "Information"
        Write-Log.ps1 -Message "This script rocks!" -Severity "Information"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]`$Message,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]`$Severity = 'Information'
    )

    Write-Host "`$(Get-Date -f g) - `$Severity : `$Message"

    New-Item -Path "`$env:HOMEDRIVE\Temp" -Name `$ScriptLogsDirName -ItemType "directory" -Force | Out-Null
    New-Item -Path "`$env:HOMEDRIVE\Temp\`$ScriptLogsDirName" -Name `$projectDirName -ItemType "directory" -Force | Out-Null

    [pscustomobject]@{
        Time       = (Get-Date -f g)
        Message    = `$Message
        Severity   = `$Severity
        ScriptName = `$ScriptName
        Host       = `$env:computername
    } | Export-Csv -Path "`$env:HOMEDRIVE\Temp\`$ScriptLogsDirName\`$projectDirName\`$(`$ScriptName)_LogFile.csv" -Append -NoTypeInformation -Force
    Set-ItemProperty -Path "`$env:HOMEDRIVE\Temp\`$ScriptLogsDirName\`$projectDirName\`$(`$ScriptName)_LogFile.csv" -Name IsReadOnly -Value `$true
}
"@

        Remove-Item "utils\$utilTitle.ps1" -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path "utils" -ErrorAction SilentlyContinue | Out-Null
        Add-Content "utils\$utilTitle.ps1" -Value $utilFILE -Force
    }

    function GenerateUTILTemplate {
        <#
    .NOTES
        Name: GenerateUTILTemplate
        Author: Edge Fabre
        Date created: 2/21/2020
    .SYNOPSIS
        Writes a template utility powershell
    .DESCRIPTION
        Writes a template utility powershell
    .PARAMETER utilTitle
        Utility File Name
    .PARAMETER utilAuthor
        Utility Author
    .PARAMETER utilDesc
        Utility Description
    .INPUTS
        System.String. Requires Title, Author and Description of the Utility script
    .OUTPUTS
        Powershell File saved to utils directory
    .EXAMPLE
        GenerateUTILTemplate "GeneralUtil" "Edge Fabre" "General Utility that does general things"
    #>
        param (
            [Parameter(Position = 0, Mandatory = $false)]    
            [String]$utilTitle,
            [Parameter(Position = 1, Mandatory = $false)]    
            [String]$utilAuthor,
            [Parameter(Position = 2, Mandatory = $false)]    
            [String]$utilDesc
        )

        if ($Test) {
            $utilTitle = "testutil"
            $utilAuthor = "Edge F"
            $utilDesc = "Test Utility"
        }
        else {
            Write-Host "Supply values for the following parameters:"
            $utilTitle = Read-Host -Prompt "utilTitle:"
            if ([string]::IsNullOrWhiteSpace($utilTitle)) {
                return
            }
            $utilAuthor = Read-Host -Prompt "utilAuthor:"
            if ([string]::IsNullOrWhiteSpace($utilAuthor)) {
                return
            }
            $utilDesc = Read-Host -Prompt "utilDesc:"
            if ([string]::IsNullOrWhiteSpace($utilDesc)) {
                return
            }
        }

        $utilFILE = @"
`$projectDirName = Split-Path (Split-Path (Split-Path `$MyInvocation.MyCommand.Definition -Parent)) -Leaf
`$ScriptName = (Get-Item `$MyInvocation.PSCommandPath).Basename  
    
function $utilTitle {
    <#
    .NOTES
        Name: $utilTitle.ps1
        Author: $utilAuthor
        Date created: $(Get-Date -Format "MM-dd-yyyy")
    .SYNOPSIS
        $utilDesc
    .DESCRIPTION
        $utilDesc
    .PARAMETER ExampleParam
        [PLACEHOLDER]
    .INPUTS
        [PLACEHOLDER]
    .OUTPUTS
        [PLACEHOLDER]
    .EXAMPLE
        [PLACEHOLDER]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]`$ExampleParam
    )
    # Insert Code Below
    
}    
"@

        Remove-Item "utils\$utilTitle.ps1" -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path "utils" -ErrorAction SilentlyContinue | Out-Null
        Add-Content "utils\$utilTitle.ps1" -Value $utilFILE -Force
    }

    if ($Build) {
        BuildProject
    }
    elseif ($Reset) {
        UpdateProjectVersion
    }
    elseif ($Publish) {
        PublishProject($ARGorSTRING)
    }
    elseif ($Flush) {
        FlushProjectReleases
    }
    elseif ($Init) {
        InitProjectInfo
    }
    elseif ($GetInfo) {
        GetProjectInfo
    }
    elseif ($SetInfo) {
        SetProjectInfo
    }
    elseif ($SemVer) {
        SemVer
    }
    elseif ($Develop) {
        Develop($ARGorSTRING)
    }
    elseif ($GenUTIL) {
        GenerateUTILTemplate
    }
    elseif ($AddDeps) {
        AddRepos($ARGorSTRING)
    }
    elseif ($LoadDeps) {
        LoadDependencies
    }
    elseif ($ListDeps) {
        ListDependencies
    }
    elseif ($GetGitBranchURL) {
        GetGithubDefaultBranchURL($ARGorSTRING)
    }
    else {
        if ($Test -eq $false) {
            Write-Host @"
usage: ManagePSProject [-Build] [-Reset] [-Publish] [-Flush] 
                        [-Init] [-GetInfo] [-SetInfo] [-SemVer] 
                        [-Develop] [-GenUTIL] [-AddDeps] [-ListDeps]

ManagePSProject -Build # Packages project and increments version number
ManagePSProject -Reset # Resets project's info
ManagePSProject -Publish `"Sample Commit Message`" # Pushes this repository to remote git repo
ManagePSProject -Flush # Clears 'releases' folder
ManagePSProject -Init # Initializes projectinfo config file for the project and builds project environment
ManagePSProject -GetInfo # Returns the current information of project
ManagePSProject -SetInfo # Sets information of project
ManagePSProject -SemVer # Returns the current Semantic Version
ManagePSProject -Develop `"Arguments for main script`" # Runs application in development mode
ManagePSProject -GenUTIL # Generates Utility for Project saved to utils folder
ManagePSProject -AddDeps "https://github.com/random/repo" # Adds a powershell github repo to script session, can add several by using space delimiter
ManagePSProject -ListDeps # Displays the dependencies of this project
"@   
        }
    }
}
