$modulespath = ($env:psmodulepath -split ";")[0]
$manageprojectpath = "$modulespath\ManagePSProject"
New-Item -Type Container -Force -path $manageprojectpath | out-null
Copy-Item "ManagePSProject.psm1" $manageprojectpath
# New-ModuleManifest -Path "$manageprojectpath\ManagePSProject.psd1" -ModuleVersion "1.0" -Author "Edge Fabre" -Description "This project contains my ManagePSProject module which is used to maintain a powershell project during it's lifecycle."
# Publish-Module -Name "ManagePSProject" -NuGetApiKey "oy2gp3tcq45dkjfhji3qb2z2tehtwcke7b2gr6a6kqyjsa"