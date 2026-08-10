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

  set {
    name  = "ingressController.installCRDs"
    value = "true"
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

resource "kubernetes_manifest" "kong_ingress_class" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "IngressClass"
    metadata = {
      name = "kong"
    }
    spec = {
      controller = "ingress-controllers.konghq.com/kong"
    }
  }
  depends_on = [helm_release.kong]
}

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
