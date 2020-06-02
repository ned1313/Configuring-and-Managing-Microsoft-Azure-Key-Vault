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
    Sku = "Premium"
}

$keyVault = New-AzKeyVault @keyVaultParameters

#Grant yourself access to the Key Vault
# Give your user principal access to all storage account permissions, on your Key Vault instance
$accessPolicy = @{
    VaultName = $keyVault.VaultName
    UserPrincipalName = "USER_PRINCIPAL_NAME"
    PermissionsToStorage = ("get","list","listsas","delete","set","update","regeneratekey","recover","backup","restore","purge")
}

Set-AzKeyVaultAccessPolicy @accessPolicy

$keyVault | Format-List

#Create a new storage account
$saAccountParameters = @{
    Name = "$($prefix)sa$id"
    ResourceGroupName = $keyVaultGroup.ResourceGroupName
    Location = $location
    SkuName = "Standard_LRS"
}

$storageAccount = New-AzStorageAccount @saAccountParameters

Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName

$keyVaultSpAppId = "cfa8b339-82a2-471a-a3c9-0fc0be7a4093"

New-AzRoleAssignment -ApplicationId $keyVaultSpAppId -RoleDefinitionName 'Storage Account Key Operator Service Role' -Scope $storageAccount.Id

# Add your storage account to your Key Vault's managed storage accounts
$managedStorageAccount = @{
    VaultName = $keyVault.VaultName
    AccountName = $storageAccount.StorageAccountName
    AccountResourceId = $storageAccount.Id
    ActiveKeyName = "key1"
    RegenerationPeriod = [System.Timespan]::FromDays(90)
}

Add-AzKeyVaultManagedStorageAccount @managedStorageAccount

Get-AzKeyVaultManagedStorageAccount -VaultName $keyVault.VaultName

Update-AzKeyVaultManagedStorageAccountKey -VaultName $keyVault.VaultName -AccountName $storageAccount.StorageAccountName -KeyName "key1"

