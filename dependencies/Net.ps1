<#
  ╓──────────────────────────────────────────────────────────────────────────────────────
  ║   PowerShell Core Module
  ╙──────────────────────────────────────────────────────────────────────────────────────
 #>



function Save-OnlineFile{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [Alias('u')]
        [string]$Url,
        [Parameter(Mandatory=$false)]
        [Alias('Destination', 'p')]
        [string]$Path
    )

    if( -not ($PSBoundParameters.ContainsKey('Path') )){
        $Path = (Get-Location).Path
        [Uri]$Val = $Url;
        $Name = $Val.Segments[$Val.Segments.Length-1]
        $Path = Join-Path $Path $Name
        Write-Warning ("NetGetFileNoCache using path $Path")
    }
    $ForceNoCache=$True

    $client = New-Object Net.WebClient
  
    $Client.Headers.Add("user-agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1") 
    

    $RequestUrl = "$Url"

    if ($ForceNoCache) {
        # doesn’t use the cache at all
        $client.CachePolicy = New-Object Net.Cache.RequestCachePolicy([Net.Cache.RequestCacheLevel]::NoCacheNoStore)

        $RandId=(new-guid).Guid
        $RandId=$RandId -replace "-"
        $RequestUrl = "$Url" + "?id=$RandId"
    }
    Write-Verbose "NetGetFileNoCache: Requesting $RequestUrl"
    $client.DownloadFile($RequestUrl,$Path)
}