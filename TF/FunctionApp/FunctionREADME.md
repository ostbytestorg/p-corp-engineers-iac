# Assign MS Graph App Permissions to a Managed Service Identity (MSI)

This guide explains how to assign Microsoft Graph app permissions to a Managed Service Identity (MSI).

## 1. Assign an App Role to the MSI

Make a `POST` request to assign an app role to the MSI's service principal:

~~~http
POST https://graph.microsoft.com/v1.0/servicePrincipals/<MSI_SERVICE_PRINCIPAL_OBJECT_ID>/appRoleAssignments
~~~

**Request Body:**

~~~json
{
  "appRoleId": "5b567255-7703-4780-807c-7be8301ae99b",  // The ID of the App Role you want to assign
  "principalId": "<MSI_SERVICE_PRINCIPAL_OBJECT_ID>",      // The MSI's service principal object ID
  "resourceId": "<YOUR MSI OBJECT ID>"        // The MS Graph service principal object ID
}
~~~

## 2. Retrieve the Required Object IDs and App Roles

### Get the MS Graph Service Principal Object ID

Execute the following GET request using the MS Graph app's well-known App ID:

~~~http
GET https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '00000003-0000-0000-c000-000000000000'&$select=id
~~~

### View Available App Roles and OAuth2 Permission Scopes

Query the MS Graph service principal to see the available app roles and scopes:

~~~http
GET https://graph.microsoft.com/v1.0/servicePrincipals/<MS_GRAPH_SP_OBJECT_ID>?$select=appRoles,oauth2PermissionScopes
~~~

### Find Your MSI Service Principal Object ID

**Option 1: Using the Azure Portal**

1. Go to the [Azure Portal](https://portal.azure.com).
2. Navigate to **Enterprise Applications**.
3. Filter by **Managed Identities**.
4. Select your MSI and note the **Object ID** from the overview.

**Option 2: Using the Graph API**

Run the following GET request to search by your MSI's display name:

~~~http
GET https://graph.microsoft.com/v1.0/servicePrincipals?$filter=displayName eq '<YOUR_MSI_DISPLAY_NAME>' and servicePrincipalType eq 'ManagedIdentity'&$select=id
~~~