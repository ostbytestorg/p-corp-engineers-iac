## Overview of Pipelines

This project leverages GitHub Actions workflows to fully provision and configure your AKS cluster, ensuring that ArgoCD is deployed and integrated with Entra SSO via Dex. The pipelines are divided into two parts:

---

### 1. **Deploy AKS & ACR via Terraform**

- **Purpose:**  
  Provision the necessary infrastructure (AKS cluster and ACR) using Terraform.

- **Key Steps:**  
  - **Azure Login:**  
    Authenticates to Azure using federated credentials via GitHub Actions.
  - **Terraform Plan & Apply:**  
    Uses a reusable Terraform workflow (triggered on pull requests affecting `TF/AKS/**` or on pushes to `main`) to deploy and manage the cluster's infrastructure, including details like node sizes.

- **Triggers & Permissions:**  
  - Triggered by changes in the `TF/AKS/**` folder and via manual dispatch.
  - Uses minimal permissions (`id-token: write` and `contents: read`) for secure automation.

---

### 2. **Configure AKS Cluster**

- **Purpose:**  
  Configure the AKS cluster post-provisioning. This includes deploying ArgoCD and setting up Entra SSO integration via Dex.

- **Key Steps:**  
  - **Repository Checkout & Azure Login:**  
    Checks out the repo and logs into Azure using federated credentials.
  - **AKS Context Configuration:**  
    Sets the AKS cluster context and installs `kubelogin` to enable noninteractive login.
  - **ArgoCD Deployment:**  
    Installs ArgoCD into a dedicated `argocd` namespace on the cluster.
  - **Expose ArgoCD Externally:**  
    Patches the ArgoCD server Service to a `LoadBalancer`, retrieves the assigned public IP, and makes it available for subsequent steps.
  - **Dex Configuration for Entra SSO:**  
    Patches the `argocd-cm` ConfigMap with a `dex.config` that wires ArgoCD to Entra SSO using a preconfigured Entra App Registration.  
    The patch substitutes runtime values for:
    - **Client ID**
    - **Client Secret**
    - **Tenant ID**
    - **ArgoCD Server URL** (used in the redirect URI)
  - **Optional ArgoCD RBAC Configuration:**  
    Configures RBAC by mapping an Azure AD security group to an ArgoCD role, ensuring the right access controls.

- **Configuration Dependencies:**  
  - Relies on a pre-registered Entra (Azure AD) application with the `clientID`, `clientSecret`, and `tenantID`.
  - These sensitive values are stored as GitHub repository secrets and injected into the pipeline.
  - The ArgoCD integration ultimately centralizes future cluster operations and continuous configuration management through its UI and GitOps model.

---

### **Outcome**

- **Infrastructure Provisioning:**  
  AKS (and related resources like ACR) are created using Terraform.
- **Cluster Configuration:**  
  The AKS cluster gets configured with a fully functional ArgoCD deployment.
- **SSO Integration:**  
  ArgoCD is set up to use Entra SSO via Dex, enabling secure and centralized authentication.
- **Future Operations:**  
  Once ArgoCD is running, further application deployments and configuration changes will be managed via GitOps.

This structured approach ensures that your AKS cluster is not only deployed but also ready for secure operations managed through ArgoCD.