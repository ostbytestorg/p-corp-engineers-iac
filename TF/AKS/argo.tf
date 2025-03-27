data "http" "argocd_install" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

resource "kubernetes_manifest" "argocd" {
  manifest = yamldecode(data.http.argocd_install.body)
}