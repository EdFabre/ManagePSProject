[![Build status](https://ci.appveyor.com/api/projects/status/m1hbibhfaauy6tbj?svg=true)](https://ci.appveyor.com/project/EdFabre/managepsproject)

# ManagePSProject

This project contains my ManagePSProject module which is used to maintain a powershell project during it's lifecycle.

## Getting Started

TBD

```powershell
# Import Module
Import-Module ManagePSProject

# Execute File using Init Flag
ManagePSProject -Init

```

## Maintaining Project

This project uses the ManagePSProject module which is used to maintain this project during it's lifecycle. See the below commands:

```powershell
# Possible Commands
ManagePSProject [-Build] [-Reset] [-Publish] [-Flush] [-Init] [-GetInfo] [-SetInfo] [SemVer]

ManagePSProject -Build # Packages project and increments version number
ManagePSProject -Reset # Resets project's info
ManagePSProject -Publish "Sample Commit Message" # Pushes this repository to remote git repo
ManagePSProject -Flush # Clears 'releases' folder
ManagePSProject -Init # Initializes projectinfo config file for the project and builds project environment
ManagePSProject -GetInfo # Returns the current information of project
ManagePSProject -SetInfo # Sets information of project
ManagePSProject -SemVer # Returns the current Semantic Version
ManagePSProject -Develop "Arguments for main script" # Runs application in development mode
ManagePSProject -GenUTIL # Generates Utility for Project saved to utils folder
```
