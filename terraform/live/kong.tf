resource "kubernetes_namespace" "kong" {
  metadata {
    name = "kong"
  }
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Kong Ingress Controller (DB-less mode) — installs its CRDs on first install.
resource "helm_release" "kong" {
  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = kubernetes_namespace.kong.metadata[0].name
  version    = "2.44.0"

  # Don't block/rollback on pod readiness — we want the release recorded
  # (and CRDs owned by Helm) even if pods are slow to come up, so we can
  # debug pod status directly with kubectl instead of losing the CRDs
  # to another rollback.
  wait    = false
  timeout = 600

  # Helm's built-in crds/ folder mechanism already installs the CRDs
  # unconditionally on first `helm install` (untracked by the release).
  # Leaving this "true" makes the chart ALSO try to install/manage the
  # same CRDs as regular Helm-tracked resources, which collides with the
  # untracked ones and fails with "invalid ownership metadata".
  set {
    name  = "ingressController.installCRDs"
    value = "false"
  }
  set {
    name  = "proxy.type"
    value = "LoadBalancer"
  }
  set {
    name  = "env.database"
    value = "off"
  }
  
  set {
    name  = "admin.enabled"
    value = "true"
  }
  set {
    name  = "admin.http.enabled"
    value = "true"
  }

  set {
    name  = "ingressController.env.log_level"
    value = "debug"
  }
}

resource "time_sleep" "wait_for_kong_crds" {
  depends_on      = [helm_release.kong]
  create_duration = "30s"
}

# The Kong Helm chart's ingress controller creates its own IngressClass named
# "kong" by default, so a separate kubernetes_manifest for it here would
# conflict ("resource already exists"). Not managing it in Terraform.

# Kong plugin manifests (kubernetes_manifest.plugin_*) live in kong-plugins.tf,
# split out because they depend on CRDs the same helm_release.kong install creates —
# see the "first-time deploy" phased-apply steps in README.md.
