# NetBox Deployment via Flux & Helm

This directory manages the deployment of NetBox and its dependencies using FluxCD and Helm.

## Components:
- **NetBox**: Official [Helm chart](https://github.com/netbox-community/netbox-chart)
- **Databases**: PostgreSQL and Redis via Bitnami Helm charts.

## Secrets Management
Sensitive information is managed securely via SOPS or External Secrets Operator.

## Deployment & Updates
Flux automatically reconciles manifests. To update, modify manifests in Git and push changes.

## Documentation:
- [NetBox Helm Chart](https://github.com/netbox-community/netbox-chart)
- [FluxCD Documentation](https://fluxcd.io/docs/)
