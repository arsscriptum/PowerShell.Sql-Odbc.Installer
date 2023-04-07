

. "$PSScriptRoot\dependencies\Net.ps1"

function Invoke-IsAdministrator  {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}


function Install-OdbcDrivers{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    try{
        $MySQL_Connector64 = "https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-noinstall-8.0.32-winx64.zip"
        $Connector_Install_PAth = "$HOME\mysql-connector"
        $LocalFile = "$ENV:Temp\mysql-connector-odbc-noinstall-8.0.32-winx64.zip"

        Write-Host "Downloading mysql-connector-odbc-noinstall-8.0.32-winx64.zip..." -n -f DarkCyan
        #Save-OnlineFile -Url "$MySQL_Connector64" -Path "$LocalFile"

        if(!(Test-PAth $LocalFile)){
            throw "error getting mysql-connector-odbc-noinstall-8.0.32-winx64"
        }
        Write-Host "OK" -f DarkGreen
        
        Write-Host "EXTRACTING mysql-connector-odbc-noinstall-8.0.32-winx64.zip..." -n -f DarkCyan
        try{
            $Null = New-Item -PAth "$Connector_Install_PAth" -ItemType Directory -Force -ErrorAction Ignore
            Expand-Archive -Path "$LocalFile" -DestinationPath "$Connector_Install_PAth" -Force -ErrorAction Ignore
        }catch{
            Write-Host "$_" -f DarkYellow
        }
        Write-Host "OK" -f DarkGreen
        $ConnectorPath = Join-Path "$Connector_Install_PAth" "mysql-connector-odbc-noinstall-8.0.32-winx64"
        $ConnectorInstall = Join-Path "$ConnectorPath" "Install.bat"
        $ConnectorUninstall = Join-Path "$ConnectorPath" "Uninstall.bat"
        $myodbcinstaller = Join-Path "$ConnectorPath" "bin\myodbc-installer.exe"

        pushd $ConnectorPath
        try{
            $UninstallOut = &"$ConnectorUninstall"    
            $DriverList_Before = &"$myodbcinstaller" "-d" "-l"
            &"$ConnectorInstall"    
            $DriverList_After = &"$myodbcinstaller" "-d" "-l"
        }catch{
            Write-Host "$_" -f DarkYellow
        }

        


        $NewDrivers = Compare-Object $DriverList_After $DriverList_Before | select -ExpandProperty  InputObject
        $NewDriversCount = $NewDrivers.Count
        
        ForEach($drv in $NewDrivers){
            Write-Host "New Driver Installed: $drv" -f DarkCyan
        }
        Write-Host "MySQL ODBC 8.0 ANSI Driver " -n  -f DarkCyan
        $DriverList_After.Contains("MySQL ODBC 8.0 ANSI Driver")
        Write-Host "MySQL ODBC 8.0 Unicode Driver " -n  -f DarkCyan
        $DriverList_After.Contains("MySQL ODBC 8.0 Unicode Driver")
        popd
    }catch{
        Write-Error "$_"
    }
}




function Install-DataSource{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataSourceName,
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,
        [Parameter(Mandatory=$true)]
        [string]$SqlUsername,
        [Parameter(Mandatory=$true)]
        [string]$SqlPassword,
        [Parameter(Mandatory=$false)]
        [string]$DriverName="MySQL ODBC 8.0 Unicode Driver"
    )
    try{
        if(-not (Invoke-IsAdministrator)) { throw "Backup mode requires Admin privileges" }

        $Connector_Install_PAth = "$HOME\mysql-connector"
        $ConnectorPath = Join-Path "$Connector_Install_PAth" "mysql-connector-odbc-noinstall-8.0.32-winx64"
        $myodbcinstaller = Join-Path "$ConnectorPath" "bin\myodbc-installer.exe"
        $DataSourceInfo = "DRIVER={0};SERVER={1};DATABASE={2};UID={3};PWD={4}" -f $DriverName, $Server,$DatabaseName,$SqlUsername,$SqlPassword
        $DataSourceInfo_Out = &"$myodbcinstaller" '-s' '-a' -'c2' '-n' "$DataSourceName" '-t' "`"$DataSourceInfo`""

        Write-Host "New DataSource `"$DataSourceName`" : " -n
        if('Success' -eq $DataSourceInfo_Out){
            Write-Host "SUCCESS" -f DarkGreen
        }else{
            Write-Host "FAILURE`n$DataSourceInfo_Out" -f DarkRed
        }
    }catch{
        Write-Error "$_"
    }
}



function Test-DataSource{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataSourceName,
        [Parameter(Mandatory=$true)]
        [string]$SqlUsername,
        [Parameter(Mandatory=$true)]
        [string]$SqlPassword
    )
    try{
    [System.Data.Odbc.OdbcConnection]$connection = [System.Data.Odbc.OdbcConnection]::new()

    $connection.ConnectionString = "DSN={0};Uid={1};Pwd={2}" -f $DataSourceName, $SqlUsername,$SqlPassword
    $connection.Open()
    return $True
    }catch{
        Write-Error "$_"
        $Res = $False
    }finally{
        $connection.Close()
        $connection.Dispose()
    }

    return $Res
}


 try{
    $Script:DataSourceName     = 'mypwshdb'    
    $Script:SqlAuthLogin       = 'pwsh'        
    $Script:SqlAuthPw          = 'secret'   

    if(-not (Invoke-IsAdministrator)) { throw "Backup mode requires Admin privileges" }
    Install-OdbcDrivers

    Install-DataSource -DataSourceName "$Script:DataSourceName" -Server "localhost" -DatabaseName "powershell" -SqlUsername "$Script:SqlAuthLogin" -SqlPassword "$Script:SqlAuthPw"

    $OdbcDsn = Get-OdbcDsn | Where Name -match "$Script:DataSourceName"
    if($OdbcDsn -eq $Null){throw "Cannot find ODBC source Script:DataSourceName"}
    $ConnectionSuccessful = Test-DataSource -DataSourceName "$Script:DataSourceName" -SqlUsername "$Script:SqlAuthLogin" -SqlPassword "$Script:SqlAuthPw"

    Write-Host "Connection to DB: $ConnectionSuccessful"

}catch{
    Write-Error "$_"
        
}