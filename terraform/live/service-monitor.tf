resource "kubernetes_manifest" "backend_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "backend"
      namespace = "default"
    }
    spec = {
      selector = {
        matchLabels = {
          app = "backend"
        }
      }
      endpoints = [
        {
          port = "backend"
          path = "/metrics"
        }
      ]
    }
  }
  depends_on = [time_sleep.wait_for_kong_crds, helm_release.kube_prometheus_stack]
}
