Param(
[string]$DNSZoneName,
[string]$HostnameToUpdate
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$IP = Invoke-RestMethod ipinfo.io -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IP

if ($IP) {
    $dnszone = Get-AzResource -ResourceName $DNSZoneName -ResourceType Microsoft.Network/dnszones
    $currentIP = (Get-AzDnsRecordSet -Name $HostnameToUpdate -ZoneName $dnszone.name -ResourceGroupName $dnszone.ResourceGroupName -RecordType A).records | Select-Object -ExpandProperty Ipv4Address
    if ($IP -ne $currentIP) {
        $RecordSet = Get-AzDnsRecordSet -Name $HostnameToUpdate -ZoneName $dnszone.name -ResourceGroupName $dnszone.ResourceGroupName -RecordType A
        Remove-AzDnsRecordConfig -RecordSet $RecordSet -Ipv4Address $currentIP
        Add-AzDnsRecordConfig -RecordSet $RecordSet -Ipv4Address $IP
        Set-AzDnsRecordSet -RecordSet $RecordSet
        $testIP = (Get-AzDnsRecordSet -Name $HostnameToUpdate -ZoneName $dnszone.name -ResourceGroupName $dnszone.ResourceGroupName -RecordType A).records | Select-Object -ExpandProperty Ipv4Address
        if ($testip -eq $IP){
            Write-Output "Successfully set IP to $IP"
        } else {
            Write-Output "Failed to update IP as expected."
        }
    } else {
        Write-Output "The current and new IPs are equal, no changes are needful."
    }
} else {
    Write-Error "No public IP was detected. Something has gone horribly wrong. Investigation needful."
    exit
}
