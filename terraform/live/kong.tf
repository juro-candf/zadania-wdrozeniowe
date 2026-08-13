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
}

resource "time_sleep" "wait_for_kong_crds" {
  depends_on      = [helm_release.kong]
  create_duration = "30s"
}

# The Kong Helm chart's ingress controller creates its own IngressClass named
# "kong" by default, so a separate kubernetes_manifest for it here would
# conflict ("resource already exists"). Not managing it in Terraform.

resource "kubernetes_manifest" "plugin_rate_limiting" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "rate-limiting"
      namespace = "default"
    }
    plugin = "rate-limiting"
    config = {
      minute = 60
      policy = "local"
    }
  }
  depends_on = [time_sleep.wait_for_kong_crds]
}

resource "kubernetes_manifest" "plugin_cors" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "cors"
      namespace = "default"
    }
    plugin = "cors"
    config = {
      origins     = ["*"]
      methods     = ["GET", "POST", "DELETE", "OPTIONS"]
      headers     = ["Accept", "Content-Type", "Authorization"]
      credentials = true
    }
  }
  depends_on = [time_sleep.wait_for_kong_crds]
}

resource "kubernetes_manifest" "plugin_request_size_limiting" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "request-size-limiting"
      namespace = "default"
    }
    plugin = "request-size-limiting"
    config = {
      allowed_payload_size = 10
    }
  }
  depends_on = [time_sleep.wait_for_kong_crds]
}

resource "kubernetes_manifest" "plugin_prometheus" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongClusterPlugin"
    metadata = {
      name   = "prometheus"
      labels = { global = "true" }
    }
    plugin = "prometheus"
  }
  depends_on = [time_sleep.wait_for_kong_crds]
}
