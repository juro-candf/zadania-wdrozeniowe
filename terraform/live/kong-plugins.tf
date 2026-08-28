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
      minute = 200
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
      allowed_payload_size = 50
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
