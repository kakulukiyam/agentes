# ==============================================================================
# Outputs de la Fase de Bootstrap
# ==============================================================================

output "github_actions_role_arn" {
  description = "ARN del Rol IAM OIDC que se debe configurar en GitHub Actions como secreto o variable"
  value       = aws_iam_role.github_actions_role.arn
}

output "terraform_state_bucket" {
  description = "Nombre del bucket S3 para el backend remoto de Terraform"
  value       = aws_s3_bucket.tf_state.id
}

output "terraform_lock_table" {
  description = "Nombre de la tabla DynamoDB para el bloqueo de estado (State Locking)"
  value       = aws_dynamodb_table.tf_locks.name
}

output "aws_region" {
  description = "Región de AWS configurada"
  value       = var.aws_region
}
