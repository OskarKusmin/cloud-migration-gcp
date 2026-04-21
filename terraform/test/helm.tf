resource "helm_release" "argocd" {
  name = "argocd"
  namespace = "argocd"
  create_namespace = true
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  version = "7.8.13"
  wait = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        nodeSelector = {
          role = "tools"
        }
        tolerations = [
          {
            key = "role"
            value = "tools"
            effect = "NoSchedule"
          }
        ]
      }
      configs = {
        params = {
          "server.insecure" = true
        }
        cm = {
          "accounts.gitlab-ci" = "apiKey"
          "resource.exclusions" = yamlencode([
            {
              apiGroups = ["cloud.google.com"]
              kinds     = ["FrontendConfig", "BackendConfig"]
              clusters  = ["*"]
            }
          ])
        }
        rbac = {
          "policy.csv" = <<-EOT
            p, gitlab-ci, applications, get, */*, allow
            p, gitlab-ci, applications, update, */*, allow
            p, gitlab-ci, applications, sync, */*, allow
            p, gitlab-ci, applications, override, */*, allow
            p, gitlab-ci, applications, action/*, */*, allow
            p, gitlab-ci, projects, get, *, allow
          EOT
        }
      }
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = "argocd.test-public.${var.domain}"
          }
        }
        ingress = {
          enabled = false
        }
      }
    })
  ]
  depends_on = [ module.gke ]
}