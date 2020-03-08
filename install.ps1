$modulespath = ($env:psmodulepath -split ";")[0]
$manageprojectpath = "$modulespath\ManagePSProject"
New-Item -Type Container -Force -path $manageprojectpath | out-null
Copy-Item "ManagePSProject.psm1" $manageprojectpath
$manifest = @{
    Path          = "$manageprojectpath\ManagePSProject.psd1"
    RootModule    = "$manageprojectpath\ManagePSProject.psm1"
    ModuleVersion = "1.20"
    Author        = "Edge Fabre"
    Description   = "This project contains my ManagePSProject module which is used to maintain a powershell project during it's lifecycle."
}
New-ModuleManifest @manifest
Publish-Module -Name "ManagePSProject" -NuGetApiKey "oy2jvyjdbzjyc3wnsa4aww5td3wnndneljdlednyot7b6u"