# ================================================================================
# OUTPUTS
# Valores úteis exibidos após o terraform apply.
# O IP público da task não é conhecido antes do deploy, mas a URL do ECR
# é necessária para configurar o pipeline.
# ================================================================================
output "ecr_repository_url" {
  description = "URL do repositório ECR - configurado como ECR_REPOSITORY_URL nas variáveis de CI/CD do GitLab"
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS - usado no comando aws ecs update-service do pipeline"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS - usado no comando aws ecs update-service do pipeline"
  value       = aws_ecs_service.this.name
}
