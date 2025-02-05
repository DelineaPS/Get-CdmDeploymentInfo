# required dll dependancy

# if it is not found, exit
if (-Not (Test-Path 'C:\Program Files\Centrify\Licensing Service\Centrify.Licensing.Logic.dll'))
{
    Write-Warning 'Required Centrify.Licensing.Logic.dll not found. Exiting.'
    Write-Warning 'check C:\Program Files\Centrify\Licensing Service\Centrify.Licensing.Logic.dll'
    Write-Warning 'Ensure Licensing Service is installed.'
    Exit 1
}

# importing required dll
Import-Module 'C:\Program Files\Centrify\Licensing Service\Centrify.Licensing.Logic.dll'

###########
#region ### Classes
###########

# base CentrifyObject
class CentrifyObject
{
    [System.String]$Domain

    CentrifyObject() {}
}# class CentrifyObject

class LicenseKey : CentrifyObject
{
    [System.String]$Key
    [System.String]$Product

    LicenseKey () {}
}

class DCLicenseKey : LicenseKey
{
    [System.String]$Type
    [System.String]$Serial
    [System.String]$Count
    [System.Boolean]$isValid
    [System.Boolean]$isEval
    [System.Boolean]$isFIPS
    [System.DateTime]$ExpiryDate

    DCLicenseKey([System.String]$d, [System.String]$p, [System.String]$k)
    {
        $this.Domain = $d
        $this.Product = $p
        $this.Key    = $k.Split(":")[1]

        $li = New-Object Centrify.Licensing.Logic.DirectControl.DCLicenseInfo -ArgumentList ($this.Key,(Get-Date),(Get-Date).AddDays(-5),"NULL")
        
        $this.Type       = $li.Type
        $this.Serial     = $li.Serial
        $this.Count      = $li.Count
        $this.isValid    = $li.IsValid
        $this.isEval     = $li.IsEval
        $this.isFIPS     = $li.IsFIPS
        $this.ExpiryDate = $li.ExpiryDate
    }# DCLicenseKey([System.String]$d, [System.String]$p, [System.String]$k)
}# class DCLicenseKey : LicenseKey

class DALicenseKey : LicenseKey
{
    [System.String]$Type
    [System.String]$SerialNumber
    [System.String]$NumberofSeats
    [System.Boolean]$isValid
    [System.Boolean]$isEval
    [System.Boolean]$isLimitedEval
    [System.Boolean]$isFIPS
    [System.Boolean]$isVersion1
    [System.DateTime]$ExpiryDate

    DALicenseKey([System.String]$d, [System.String]$p, [System.String]$k)
    {
        $this.Domain = $d
        $this.Product = $p
        $this.Key    = $k.Split(":")[1]

        $li = New-Object Centrify.DirectAudit.Common.Logic.Api.LicenseKey ($this.Key,(Get-Date),(Get-Date).AddDays(-5))

        $this.Type          = $li.Type
        $this.SerialNumber  = $li.SerialNumber
        $this.NumberofSeats = $li.NumberOfSeats
        $this.isValid       = $li.IsValid
        $this.isEval        = $li.IsEval
        $this.isLimitedEval = $li.IsLimitedEval
        $this.isFIPS        = $li.IsFIPS
        $this.isVersion1    = $li.IsVersion1
        $this.ExpiryDate    = $li.ExpiryDate
    }# DALicenseKey([System.String]$d, [System.String]$p, [System.String]$k)
}# class DALicenseKey : LicenseKey

# class for zone information
class CentrifyZone : CentrifyObject
{
    [System.String]$Name
    [System.String]$ZoneType
    [System.String]$DistinguishedName

    CentrifyZone([System.String]$d, [PSObject]$z)
    {
        $this.Domain = $d
        $this.Name   = $z.name
        $this.DistinguishedName = $z.distinguishedname

        switch ($z.displayname)
        {
            '$CimsZoneVersion2' { $this.ZoneType = "ClassicSFU"       ; break }
            '$CimsZoneVersion3' { $this.ZoneType = "ClassicRFC"       ; break }
            '$CimsZoneVersion4' { $this.ZoneType = "ClassicStandard"  ; break }
            '$CimsZoneVersion7' { $this.ZoneType = "Hierarchical"     ; break }
            default             { $this.ZoneType = "Unknown"          ; break }
        }
    }
}# class CentrifyZone : CentrifyObject

# class for CdmComputer and Parent Computer information
class CentrifyComputer : CentrifyObject
{
    [System.String]$Name
    [System.String]$CdmDistinguishedName
    [System.String]$ZoneVersion
    [System.String]$ParentLink
    [System.String]$ParentDistinguishedName
    [System.String]$OperatingSystem
    [System.String]$OperatingSystemHotFix
    [System.String]$OperatingSystemServicePack
    [System.String]$OperatingSystemVersion

    CentrifyComputer([System.String]$d, [PSObject]$c)
    { 
        $this.Domain = $d
        $this.Name   = $c.name
        $this.CdmDistinguishedName = $c.distinguishedname
        #$this.OldC = $c

        switch ($c.displayname)
        {
            '$CimsComputerVersion2' { $this.ZoneVersion = "Classic"     ; break }
            '$CimsComputerVersion3' { $this.ZoneVersion = "Hiearchical" ; break }
            default                 { $this.ZoneVersion = "Unknown"     ; break }
        }
    }# CentrifyComputer([System.String]$d, [PSObject]$c)

    # adding OS information
    addOSInfo([PSObject]$o)
    {
        $this.OperatingSystem            = $o.operatingsystem
        $this.OperatingSystemHotFix      = $o.operatingsystemhotfix
        $this.OperatingSystemServicePack = $o.operatingsystemservicepack
        $this.OperatingSystemVersion     = $o.operatingsystemversion
    }
}# class CentrifyComputer : CentrifyObject

class CentrifyDeploymentInfo
{
    [System.Collections.Generic.List[DCLicenseKey]]$DCLicenseKeys = @{}
    [System.Collections.Generic.List[DALicenseKey]]$DALicenseKeys = @{}
    [System.Collections.ArrayList]$CombinedLicenseKeys = @{}
    [System.Collections.Generic.List[CentrifyZone]]$CentrifyZones = @{}
    [System.Collections.Generic.List[CentrifyComputer]]$CentrifyComputers = @{}

    CentrifyDeploymentInfo () {}
}

###########
#region ### global:Get-CdmDeploymentInfo
###########
function global:Get-CdmDeploymentInfo
{
    <#
    .SYNOPSIS
    Gets information regarding a Delinea Server Suite Deployment.

    .DESCRIPTION
    This cmdlet will search multiple domains to parse information regarding a Delinea 
    Server Suite deployment. This will produce some system and license metrics for review.

    .PARAMETER Domains
    The domains to parse. This is an array and multiple domains can be provided separated by a comma.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a unique CentrifyDeploymentInfo objects.

    .EXAMPLE
    C:\PS> Get-CdmDeploymentInfo -Domains domain1.com,domain2.com,domain3.com
    This will provide Server Suite server and license information from domain1.com, domain2.com, and domain3.com
    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "The domains to target.")]
		[System.String[]]$Domains
    )

    $DeploymentInfo = New-Object CentrifyDeploymentInfo

    foreach ($domain in $Domains)
    {
        Write-Verbose "Starting on $domain"

        ### License ###

        ## DirectControl licenses ##
    
        # setting the search for our unique tag
        $l = [ADSISearcher]'(&(displayName=$CimsLicenseContainerVersion*))' # targets license containers 

        # setting the search root
        $l.SearchRoot = [ADSI]"LDAP://$domain"

        # only get the description property
        $l.PropertiesToLoad.AddRange(@('description'))
    
        # for each license key container we found 
        foreach ($licensekey in $l.FindAll().Properties)
        {
            # and for each license key in that container
            foreach ($key in $licensekey.description)
            {
                # new license key object and add it to the deployment info
                $obj = New-Object DCLicenseKey -ArgumentList ($domain, "DirectControl", $key)
                $DeploymentInfo.DCLicenseKeys.Add($obj) | Out-Null
            }
        }# foreach ($licensekey in $l.FindAll().Properties)

        ## DirectAudit licenses ##
        
        
        # setting the search for our unique tag
        $a = [ADSISearcher]'(&(name=Vegas-Installation-*))'

        # setting the search root
        $a.SearchRoot = [ADSI]"LDAP://$domain"

        # only get the description property
        $a.PropertiesToLoad.AddRange(@('keywords'))

        foreach ($dakey in $a.FindAll().Properties)
        {
            foreach ($key in ($dakey.keywords | Where-Object {$_ -like "License:*"}))
            {
                $obj = New-Object DALicenseKey -ArgumentList ($domain, "DirectAudit", $key)
                $DeploymentInfo.DALicenseKeys.Add($obj) | Out-Null
            }
        } #>

        ### Zones ###

        # setting the search for our unique tag
        $z = [ADSISearcher]'(&(displayName=$CimsZoneVersion*))' # targets zones

        # setting the search root
        $z.SearchRoot = [ADSI]"LDAP://$domain"

        # only get the name, displayname, and distinguishedname properties
        $z.PropertiesToLoad.AddRange(@('name','displayname','distinguishedname'))

        # for each zone container we found 
        foreach ($zone in $z.FindAll().Properties)
        {
            # new centrify zone object and add it to the deployment info
            $obj = New-Object CentrifyZone -ArgumentList ($domain, $zone)
            $DeploymentInfo.CentrifyZones.Add($obj) | Out-Null
        }

        ### Computers ###

        # setting the search for our unique tag
        $c = [ADSISearcher]'(&(displayName=$Cims*ComputerVersion*))' # targets Cdm computers

        # setting the search root
        $c.SearchRoot = [ADSI]"LDAP://$domain"

        # only get the name, displayname, and distinguishedname properties
        $c.PropertiesToLoad.AddRange(@('name','displayname','distinguishedname'))

        # for each Cdm computer we found
        foreach ($computer in $c.FindAll().Properties)
        {
            # new Cdm computer object and add it to the deployment info
            $obj = New-Object CentrifyComputer -ArgumentList ($domain, $computer)
            $DeploymentInfo.CentrifyComputers.Add($obj) | Out-Null
        }

        # still need to find more info about the parent computer object
        # for each cdm computer object that matches our domain
        foreach ($centrifycomputer in ($DeploymentInfo.CentrifyComputers | Where-Object -Property Domain -eq $domain))
        {
            # setting the search for the distinguished name of the cdm computer object
            $s = [ADSISearcher]"(&(distinguishedName=$($centrifycomputer.CdmdistinguishedName)))"

            # setting the search root
            $s.SearchRoot = [ADSI]"LDAP://$domain"

            # only get the keywords property
            $s.PropertiesToLoad.AddRange(@('keywords'))

            # finding that keywords property, and splitting the resulting string to only show the parent object SID
            $centrifycomputer.ParentLink = ($s.FindOne().Properties.keywords | Where-Object {$_ -like "parentLink:*"}).Split(":")[1]

            # query to get the parent computer DN
            $b = [ADSI]"LDAP://$domain/<SID=$($centrifycomputer.ParentLink)>"

            # setting the parent computer object's distiguished name
            $centrifycomputer.ParentDistinguishedName = $b.distinguishedName

            # setting the search for the distinguished name of the parent computer object
            $o = [ADSISearcher]"(&(distinguishedName=$($centrifycomputer.ParentDistinguishedName)))"

            # setting the search root
            $o.SearchRoot = [ADSI]"LDAP://$domain"

            # only get the operating system properties
            $o.PropertiesToLoad.AddRange(('operatingsystem','operatingsystemhotfix','operatingsystemservicepack','operatingsystemversion'))

            # add that info to the centrify computer object
            $centrifycomputer.AddOSInfo($o.FindOne().Properties)

        }# foreach ($centrifycomputer in ($DeploymentInfo.CentrifyComputers | Where-Object -Property Domain -eq $domain))
    }# foreach ($domain in $Domains)

    return $DeploymentInfo
}# function global:Get-CdmDeploymentInfo 
#endregion
###########

###########
#region ### global:Get-CdmLicenseKeys
###########
function global:Get-CdmLicenseKeys
{
    <#
    .SYNOPSIS
    Gets license information regarding a Delinea Server Suite Deployment.

    .DESCRIPTION
    This cmdlet will search multiple domains to parse information regarding a Delinea 
    Server Suite deployment. This will produce some license metrics for review.

    .PARAMETER Domains
    The domains to parse. This is an array and multiple domains can be provided separated by a comma.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a unique Centrify LicenseKey object.

    .EXAMPLE
    C:\PS> Get-CdmLicenseKeys -Domains domain1.com,domain2.com,domain3.com
    This will provide Server Suite license information from domain1.com, domain2.com, and domain3.com
    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "The domains to target.")]
		[System.String[]]$Domains
    )

    # get the initial metric info
    $CdmDeploymentInfo = Get-CdmDeploymentInfo -Domains $Domains

    # filter down license key information to a combined view with consolidated properties
    $dccombined = $CdmDeploymentInfo.DCLicenseKeys | Select-Object Product,Domain,Type,Serial,Count,isValid,isFIPS,ExpiryDate,Key
    $dacombined = $CdmDeploymentInfo.DALicenseKeys | Select-Object Product,Domain,Type,@{label="Serial";Expression={$_.SerialNumber}}, `
                                                        @{label="Count";Expression={$_.NumberofSeats}},isValid,isFIPS,ExpiryDate,Key

    # make a new ArrayList for this and add both sets of information
    $CombinedKeys = New-Object System.Collections.ArrayList
    $CombinedKeys.AddRange(@($dccombined)) | Out-Null
    $CombinedKeys.AddRange(@($dacombined)) | Out-Null
                                                            
    return $CombinedKeys
}# function global:Get-CdmLicenseKeys
#endregion
###########


###########
#region ### global:Get-CdmSystemCount
###########
function global:Get-CdmSystemCount
{
    <#
    .SYNOPSIS
    Gets system information regarding a Delinea Server Suite Deployment.

    .DESCRIPTION
    This cmdlet will search multiple domains to parse information regarding a Delinea 
    Server Suite deployment. This will produce some system metrics for review.

    .PARAMETER Domains
    The domains to parse. This is an array and multiple domains can be provided separated by a comma.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs to the console only.

    .EXAMPLE
    C:\PS> Get-CdmSystemCount -Domains domain1.com,domain2.com,domain3.com
    This will provide Server Suite server information from domain1.com, domain2.com, and domain3.com
    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "The domains to target.")]
		[System.String[]]$Domains
    )

    $CdmDeploymentInfo = Get-CdmDeploymentInfo -Domains $Domains

    $TotalSystems = $CdmDeploymentInfo.CentrifyComputers.Count

    Write-Host "Total System Count: " -NoNewline

    Write-Host $CdmDeploymentInfo.CentrifyComputers.Count

    Write-Host "Total System Operating Systems across all domains"

    Write-Host  ($CdmDeploymentInfo.CentrifyComputers | Group-Object -Property OperatingSystem | Select -Property Count,Name | Out-String)


    foreach ($domain in $Domains)
    {
        Write-Host "`r`n### Domain [$domain] ###`r`n"

        Write-Host "Total $domain System Count: " -NoNewline

        Write-Host ($CdmDeploymentInfo.CentrifyComputers | Where-Object -Property Domain -eq $domain | Measure-Object | Select-Object -ExpandProperty Count)

        Write-Host "Total $domain System Operating System: " -NoNewline

        Write-Host  ($CdmDeploymentInfo.CentrifyComputers | Where-Object -Property Domain -eq $domain | Group-Object -Property OperatingSystem | Select -Property Count,Name | Out-String)
    }
}# function global:Get-CdmSystemCount
#endregion
###########
