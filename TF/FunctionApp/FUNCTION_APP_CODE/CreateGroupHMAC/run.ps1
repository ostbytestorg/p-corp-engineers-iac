param($Request, $TriggerMetadata)

Write-Host "Processing CreateGroup function request..."

function Write-LogAndExit {
    param(
        [string]$Message,
        [System.Net.HttpStatusCode]$StatusCode = [System.Net.HttpStatusCode]::BadRequest
    )
    Write-Host $Message
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body = $Message
    })
    return
}

###############################
# Get Secret from Key Vault   #
###############################

function Get-KeyVaultSecret {
    param (
        [string]$SecretName,
        [string]$KeyVaultName = $env:KEYVAULT_NAME # Use environment variable
    )
    
    try {
        Write-Host "Starting Key Vault secret retrieval..."
        Write-Host "KeyVault Name: $KeyVaultName"
        Write-Host "Secret Name: $SecretName"
        
        # Check for required environment variables
        Write-Host "Identity Endpoint: $($env:IDENTITY_ENDPOINT -ne $null ? 'Present' : 'Missing')"
        Write-Host "Identity Header: $($env:IDENTITY_HEADER -ne $null ? 'Present' : 'Missing')"
        
        if (-not $env:IDENTITY_ENDPOINT -or -not $env:IDENTITY_HEADER) {
            Write-Host "ERROR: Missing required environment variables for managed identity"
            return $null
        }
        
        # Get managed identity token for Key Vault
        # Note: The resource parameter must be URL-encoded
        $resource = [System.Web.HttpUtility]::UrlEncode("https://vault.azure.net")
        $tokenAuthUri = "$($env:IDENTITY_ENDPOINT)?resource=$resource&api-version=2019-08-01"
        Write-Host "Token Auth URI: $tokenAuthUri"
        
        Write-Host "Requesting managed identity token..."
        try {
            $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthUri
            Write-Host "Token response received successfully"
            $accessToken = $tokenResponse.access_token
            Write-Host "Access token obtained successfully"
        }
        catch {
            Write-Host "ERROR getting token: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                Write-Host "Response Status Code: $($_.Exception.Response.StatusCode)"
                Write-Host "Response: $($_.Exception.Response | ConvertTo-Json -Depth 3)"
            }
            return $null
        }
        
        # Correctly format the Key Vault secret URI
        $secretUri = "https://$KeyVaultName.vault.azure.net/secrets/$SecretName" + "?api-version=7.0"
        Write-Host "Secret URI: $secretUri"
        
        Write-Host "Requesting secret from Key Vault..."
        try {
            $response = Invoke-RestMethod -Uri $secretUri -Method GET -Headers @{Authorization = "Bearer $accessToken"}
            Write-Host "Secret retrieved successfully"
            return $response.value
        }
        catch {
            Write-Host "ERROR getting secret: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                Write-Host "Response Status Code: $($_.Exception.Response.StatusCode)"
                
                # Try to get more detailed error information
                try {
                    $errorContent = $_.ErrorDetails.Message
                    Write-Host "Error Details: $errorContent"
                }
                catch {
                    Write-Host "Could not extract error details"
                }
                
                Write-Host "Response: $($_.Exception.Response | ConvertTo-Json -Depth 3)"
            }
            return $null
        }
    }
    catch {
        Write-Host "Unhandled exception in Get-KeyVaultSecret: $_"
        Write-Host "Exception details: $($_.Exception.Message)"
        Write-Host "Stack trace: $($_.ScriptStackTrace)"
        return $null
    }
}

# Get HMAC secret from Key Vault
$sharedSecretKey = Get-KeyVaultSecret -SecretName "hmac"
if (-not $sharedSecretKey) {
    Write-LogAndExit -Message "Failed to retrieve HMAC secret from Key Vault" -StatusCode ([System.Net.HttpStatusCode]::InternalServerError)
    return
}

Write-Host "Successfully retrieved secret from Key Vault"

###############################
# HMAC Authentication Section #
###############################

# Extract authentication headers
$hmacTimestamp = $Request.Headers.'x-hmac-timestamp'
$hmacSignature = $Request.Headers.'x-hmac-signature'

# Get the raw request body as string
$requestBody = $Request.RawBody
if ($null -eq $requestBody) {
    # For HTTP requests with no body
    $requestBody = ""
} else {
    # Ensure we have the body as a string
    $requestBody = [System.Text.Encoding]::UTF8.GetString($requestBody)
}

Write-Host "Verifying HMAC signature..."
Write-Host "Timestamp: $hmacTimestamp"
Write-Host "Request body length: $($requestBody.Length) bytes"

# Validate required authentication headers
if (-not $hmacTimestamp -or -not $hmacSignature) {
    Write-LogAndExit -Message "Missing required authentication headers" -StatusCode ([System.Net.HttpStatusCode]::Unauthorized)
    return
}

# Create the string to sign (timestamp + newline + requestBody)
$stringToSign = "$hmacTimestamp`n$requestBody"
Write-Host "String to sign created (not showing for security reasons)"

# Create HMAC signature
$hmacsha256 = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha256.Key = [System.Text.Encoding]::UTF8.GetBytes($sharedSecretKey)
$signatureBytes = $hmacsha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
$computedSignature = [Convert]::ToBase64String($signatureBytes)

# Check if timestamp is recent (within 5 minutes)
try {
    $timestampDate = [DateTimeOffset]::Parse($hmacTimestamp, [System.Globalization.CultureInfo]::InvariantCulture)
    $timeDifference = [DateTimeOffset]::UtcNow - $timestampDate
    $maxTimeDifference = [TimeSpan]::FromMinutes(5)

    if ($timeDifference -gt $maxTimeDifference) {
        Write-LogAndExit -Message "Request timestamp is too old" -StatusCode ([System.Net.HttpStatusCode]::Unauthorized)
        return
    }
}
catch {
    Write-LogAndExit -Message "Invalid timestamp format" -StatusCode ([System.Net.HttpStatusCode]::BadRequest)
    return
}

# Verify signature
if ($computedSignature -ne $hmacSignature) {
    Write-Host "Signature verification failed. Expected: $computedSignature"
    Write-LogAndExit -Message "Invalid signature" -StatusCode ([System.Net.HttpStatusCode]::Unauthorized)
    return
}

Write-Host "HMAC signature verified successfully!"

##################################
# Original Function Logic Begins #
##################################

# Access properties from the deserialized JSON payload 
try {
    $bodyObj = $requestBody | ConvertFrom-Json
    $groupName = $bodyObj.groupName
    $description = $bodyObj.description
}
catch {
    Write-LogAndExit -Message "Invalid JSON in request body: $($_.Exception.Message)" -StatusCode ([System.Net.HttpStatusCode]::BadRequest)
    return
}

# Validate required input
if (-not $groupName) {
    Write-LogAndExit -Message "Missing required property: groupName" -StatusCode ([System.Net.HttpStatusCode]::BadRequest)
    return
}

# Use a conditional switch to decide how to obtain the Microsoft Graph access token
if ($env:WEBSITE_SITE_NAME) {
    Write-Output "Running in Azure. Using Managed Identity."
    Write-Output "Raw Identity endpoint: [$env:IDENTITY_ENDPOINT]"
    
    $baseUrl = $env:IDENTITY_ENDPOINT
    $resource = "https://graph.microsoft.com"
    $apiVersion = "2019-08-01"
    
    $url = "${baseUrl}?resource=${resource}&api-version=${apiVersion}"
    
    Write-Output "Constructed URL components:"
    Write-Output "Base URL: [$baseUrl]"
    Write-Output "Resource: [$resource]"
    Write-Output "API Version: [$apiVersion]"
    Write-Output "Final URL: [$url]"
    
    try {
        Write-Output "Making token request..."
        $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $url
        $accessToken = $tokenResponse.access_token
        
        Write-Output "Token acquired successfully. Token prefix: $($accessToken.Substring(0,10))..."
    }
    catch {
        Write-Output "=== Token Error Details ==="
        Write-Output $_.Exception.Message
        Write-Output "Status Code: $($_.Exception.Response.StatusCode)"
        Write-Output "Status Description: $($_.Exception.Response.StatusDescription)"
        Write-Output "=== End Error Details ==="
        
        throw
    }
}
else {
    # Running locally: Use client credentials from local.settings
    Write-Host "Running locally. Using client secret flow."

    $tenantId = $env:TENANT_ID
    $clientId = $env:CLIENT_ID
    $clientSecret = $env:CLIENT_SECRET
    $scope = "https://graph.microsoft.com/.default"
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    
    try {
        $tokenResponse = Invoke-RestMethod -Method Post `
            -Uri $tokenUrl `
            -ContentType "application/x-www-form-urlencoded" `
            -Body @{
            client_id     = $clientId
            scope         = $scope
            client_secret = $clientSecret
            grant_type    = "client_credentials"
        }
    }
    catch {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [System.Net.HttpStatusCode]::InternalServerError
                Body       = "Failed to acquire token using client secret: $($_.Exception.Message)"
            })
        return
    }
    $accessToken = $tokenResponse.access_token
}

# Construct a unique mailNickname from groupName by removing spaces
$mailNickname = ($groupName -replace '\s', '')

# Your existing group creation logic continues from here
$graphUrl = "https://graph.microsoft.com/v1.0/groups"
$filterQuery = "?`$filter=mailNickname eq '$mailNickname'"
$checkUrl = "$graphUrl$filterQuery"
Write-Host "Checking for existing group with URL: $checkUrl"

try {
    $existingGroupsResponse = Invoke-RestMethod -Uri $checkUrl `
        -Method Get `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $accessToken" }
}
catch {
    Write-LogAndExit -Message "Failed to query existing groups: $($_.Exception.Message)" -StatusCode ([System.Net.HttpStatusCode]::InternalServerError)
    return
}

if ($existingGroupsResponse.value.Count -gt 0) {
    Write-Host "Group already exists. Returning the existing group."
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [System.Net.HttpStatusCode]::OK
        Body = $existingGroupsResponse.value[0]
    })
    return
}

# Prepare the request body for creating a new security group
$graphRequestBody = @{
    displayName = $groupName
    description = $description
    mailEnabled = $false
    mailNickname = $mailNickname
    securityEnabled = $true
    groupTypes = @()
} | ConvertTo-Json

# Create the group
try {
    $response = Invoke-RestMethod -Uri $graphUrl `
        -Method Post `
        -Body $graphRequestBody `
        -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $accessToken" }

    # Add audit information to response
    $response | Add-Member -NotePropertyName "approvalTime" -NotePropertyValue (Get-Date -Format "o")
}
catch {
    Write-LogAndExit -Message "Failed to create group: $($_.Exception.Message)" -StatusCode ([System.Net.HttpStatusCode]::InternalServerError)
    return
}

# Return the newly created group information
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.Net.HttpStatusCode]::OK
    Body = $response
})