resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = "default"
  }

  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_db
  }

  type = "Opaque"

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "helm_release" "app" {
  name      = "zw-app"
  chart     = "${path.module}/../helm/zw-app"
  namespace = "default"

  set {
    name  = "backend.image.tag"
    value = var.backend_image_tag
  }
  set {
    name  = "frontend.image.tag"
    value = var.frontend_image_tag
  }
  set {
    name  = "postgres.existingSecret"
    value = kubernetes_secret.postgres_credentials.metadata[0].name
  }

  depends_on = [
    kubernetes_secret.postgres_credentials,
    helm_release.kong,
    kubernetes_manifest.kong_ingress_class,
  ]
}
