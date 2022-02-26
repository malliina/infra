# Unable to do this in bicep template
Write-Host 'Enabling custom HTTPS...'
Enable-AzCdnCustomDomainHttps -ResourceGroupName $env:ResourceGroupName -ProfileName $env:ProfileName -EndpointName $env:EndpointName -CustomDomainName $env:CustomDomainName
