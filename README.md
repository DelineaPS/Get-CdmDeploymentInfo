# Get-CdmDeploymentInfo
The intent of this tool is to provide an easy way to gather metric data across multiple domains regarding Server Suite's server and license information for easy of compliance reporting.

# Running the script (Cloud Grab)

To get started, copy the snippet below and paste it directly into a PowerShell (Run-As Administrator not needed) window and run it. This effectively invokes the script from this GitHub repo directly as a web request and dot sources it into your current PowerShell session.

```
([ScriptBlock]::Create(((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/dnlrv/Get-CdmDeploytmentInfo/main/PGet-CdmDeploytmentInfo.ps1').Content))).Invoke()
```

# Using the script

The cmdlet `Get-CdmDeploymentInfo` is your primary cmdlet to gather deployment information. The cmdlet only has a single parameter, `-Domains` which can take an array of domains separated by a comma.

The script is capable of obtaining information from other domains.

## Example

Get the Server Suite deployment information from domain1.com and domain2.com
```
Get-CdmDeploymentInfo -Domains domain1.com,domain2.com
```

# How to update

As new scripts are added into whatever Folders you want, the next Cloud Grab should grab those changes.

# Disclaimer

The contents (scripts, documentation, examples) included in this repository are not supported under any Delinea standard support program, agreement, or service. The code is provided AS IS without warranty of any kind. Delinea further disclaims all implied warranties, including, without limitation, any implied warranties of merchantability or fitness for a particular purpose. The entire risk arising out of the code and content's use or performance remains with you. In no event shall Delinea, its authors, or anyone else involved in the creation, production, or delivery of the content be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the code or content, even if Delinea has been advised of the possibility of such damages.