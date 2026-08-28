resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [azurerm_kubernetes_cluster.main]
}

data "kubernetes_resource" "metrics_server" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
  }
  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "time_sleep" "wait_for_kong_lb" {
  depends_on      = [helm_release.kong]
  create_duration = "90s"
}

data "kubernetes_service" "kong_proxy" {
  metadata {
    name      = "kong-kong-proxy"
    namespace = kubernetes_namespace.kong.metadata[0].name
  }
  depends_on = [time_sleep.wait_for_kong_lb]
}

locals {
  kong_external_ip = data.kubernetes_service.kong_proxy.status[0].load_balancer[0].ingress[0].ip
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "62.7.0"

  wait    = false
  timeout = 600

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "24h"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "512Mi"
  }
  set {
    name  = "grafana.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "grafana.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "grafana.grafana\\.ini.server.domain"
    value = local.kong_external_ip
  }
  set {
    name  = "grafana.grafana\\.ini.server.root_url"
    value = "http://${local.kong_external_ip}/grafana/"
  }
  set {
    name  = "grafana.grafana\\.ini.server.serve_from_sub_path"
    value = "true"
  }

  set {
    name  = "grafana.sidecar.alerts.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_config_map" "grafana_dashboard_backend" {
  metadata {
    name      = "grafana-dashboard-backend-overview"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "backend-overview.json" = file("${path.module}/dashboards/backend-overview.json")
  }
  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "grafana_alert_rules" {
  metadata {
    name      = "grafana-alert-rules"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels    = { grafana_alert = "1" }
  }
  data = {
    "rules.yaml"         = file("${path.module}/alerts/rules.yaml")
    "contactpoints.yaml" = file("${path.module}/alerts/contactpoints.yaml")
  }
  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_secret" "grafana_basic_auth_credential" {
  metadata {
    name      = "grafana-basic-auth-credential"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "konghq.com/credential" = "basic-auth"
    }
  }
  data = {
    username = "admin"
    password = var.grafana_admin_password
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_manifest" "grafana_consumer" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongConsumer"
    metadata = {
      name      = "grafana-user"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      annotations = {
        "kubernetes.io/ingress.class" = "kong"
      }
    }
    username    = "grafana-user"
    credentials = [kubernetes_secret.grafana_basic_auth_credential.metadata[0].name]
  }
  depends_on = [time_sleep.wait_for_kong_crds, kubernetes_secret.grafana_basic_auth_credential]
}

resource "kubernetes_manifest" "grafana_basic_auth_plugin" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "grafana-basic-auth"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    plugin = "basic-auth"
  }
  depends_on = [time_sleep.wait_for_kong_crds]
}

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "konghq.com/strip-path" = "false"
      "konghq.com/plugins"    = "grafana-basic-auth"
    }
  }
  spec {
    ingress_class_name = "kong"
    rule {
      http {
        path {
          path      = "/grafana"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.kube_prometheus_stack]
}

# kubernetes_manifest.backend_service_monitor lives in service-monitor.tf, split out
# because the ServiceMonitor CRD only exists after helm_release.kube_prometheus_stack
# finishes — see the "first-time deploy" phased-apply steps in README.md.

resource "helm_release" "loki_stack" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "2.10.2"

  wait    = false
  timeout = 600

  set {
    name  = "grafana.enabled"
    value = "false"
  }
  set {
    name  = "promtail.enabled"
    value = "true"
  }
  set {
    name  = "loki.persistence.enabled"
    value = "false"
  }
  # loki-stack auto-provisions its own Grafana datasource ConfigMap; must not conflict with Prometheus's isDefault
  set {
    name  = "loki.isDefault"
    value = "false"
  }
  set {
    name  = "loki.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "loki.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "loki.resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "loki.resources.limits.memory"
    value = "256Mi"
  }
  set {
    name  = "promtail.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "promtail.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "promtail.resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "promtail.resources.limits.memory"
    value = "128Mi"
  }

  depends_on = [kubernetes_namespace.monitoring]
}