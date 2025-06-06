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

# Access properties from the deserialized JSON payload
$groupName = $Request.Body.groupName
$description = $Request.Body.description

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

# Validate approver group membership
if (-not (Test-UserInApproverGroup -UserObjectId $userObjectId -AccessToken $accessToken)) {
    Write-LogAndExit -Message "User is not an authorized approver" -StatusCode ([System.Net.HttpStatusCode]::Forbidden)
    return
}

Write-Host "Authenticated approver: $userPrincipalName ($userObjectId)"

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
    $response | Add-Member -NotePropertyName "approvedBy" -NotePropertyValue $userPrincipalName
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