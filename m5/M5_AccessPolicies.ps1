#Prefix for resources
$prefix = "cmk"

#Basic variables
$location = "eastus"
$id = Get-Random -Minimum 1000 -Maximum 9999

#Log into Azure
Add-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "SUB_NAME" | Select-AzSubscription

#Create a resource group for Key Vault
$keyVaultGroup = New-AzResourceGroup -Name "$prefix-key-vault-$id" -Location $location

#Create a new Key Vault
$keyVaultParameters = @{
    Name = "$prefix-key-vault-$id"
    ResourceGroupName = $keyVaultGroup.ResourceGroupName
    Location = $location
    Sku = "Standard"
}

$keyVault = New-AzKeyVault @keyVaultParameters

#If you already have a Key Vault
$keyVault = Get-AzKeyVault -VaultName "VAULT_NAME" -ResourceGroupName "RESOURCE_GROUP_NAME"

#Create a storage account for logs and metrics
$storageAccountParameters = @{
    ResourceGroupName = $keyVault.ResourceGroupName
    Name = "$($prefix)logs$id"
    Type = "Standard_LRS"
    Location = $location
}

$sa = New-AzStorageAccount @storageAccountParameters

#Create a Log Analytics Workspace
$logAnalyticsParameters = @{
    ResourceGroupName = $keyVault.ResourceGroupName
    Name = "$prefix-keyvaultstats-$id"
    Location = $location
    Sku = "Standard"
}

$la = New-AzOperationalInsightsWorkspace @logAnalyticsParameters

# Add solutions
$solutionParameters = @{
    ResourceGroupName = $la.ResourceGroupName
    WorkspaceName = $la.Name
    IntelligencePackName = "KeyVaultAnalytics"
    Enabled = $true
}

# Add solutions
Set-AzOperationalInsightsIntelligencePack @solutionParameters

#Update Diagnostic Settings for Key Vault
$diagnosticSettings = @{
    ResourceId = $keyVault.ResourceId
    WorkspaceId = $la.ResourceId
    MetricCategory = "AllMetrics"
    Category = "AuditEvent"
    Enabled = $true
    StorageAccountId = $sa.Id
    RetentionEnabled = $true
    RetentionInDays = 180
}

Set-AzDiagnosticSetting @diagnosticSettings

#Generate some events
$Secret = ConvertTo-SecureString -String 'ContosoSecrets' -AsPlainText -Force
ForEach($n in 1..10){Add-AzKeyVaultKey -Name "key$n" -VaultName $keyVault.VaultName -Destination Software}
ForEach($n in 1..10){Get-AzKeyVaultKey -Name "key$n" -VaultName $keyVault.VaultName}
ForEach($n in 1..10){Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name "secret$n" -SecretValue $Secret}
ForEach($n in 1..10){Get-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name "secret$n"}
ForEach($n in 1..10){Remove-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name "secret$n" -Force}

#Create an access policy for certificates
$certPolicyParameters = @{
    VaultName = $keyVault.VaultName
    ResourceGroupName = $keyVault.ResourceGroupName
    PermissionsToCertificates = @("get","list","update","create","import","delete","recover","backup","restore")
    UserPrincipalName = "BoWeber@contoso-ned.xyz"
}

Set-AzKeyVaultAccessPolicy @certPolicyParameters

#Create an access policy for keys and secrets using policy
$backupPolicyParameters = @{
    VaultName = $keyVault.VaultName
    ResourceGroupName = $keyVault.ResourceGroupName
    PermissionsToKeys = @("backup","get","list")
    PermissionsToSecrets = @("backup","get","list")
    ServicePrincipalName = "262044b1-e2ce-469f-a196-69ab7ada62d3"
}

Set-AzKeyVaultAccessPolicy @backupPolicyParameters