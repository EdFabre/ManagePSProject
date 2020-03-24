[![Build status](https://ci.appveyor.com/api/projects/status/m1hbibhfaauy6tbj?svg=true)](https://ci.appveyor.com/project/EdFabre/managepsproject)

# ManagePSProject

This project contains my ManagePSProject module which is used to maintain a powershell project during it's lifecycle.

## Getting Started

Install Module straight from Powershell Gallery using the below commands

```powershell
# Install Module
Install-Module ManagePSProject

# Execute File using Init Flag
ManagePSProject -Init
```

## How to use

The ManagePSProject module is used to maintain Powershell projects during their lifecycle. See the below commands for more information

```powershell
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
```
