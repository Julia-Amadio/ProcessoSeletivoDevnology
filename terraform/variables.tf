variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Nome base usado para nomear todos os recursos"
  type        = string
  default     = "devnology-api"
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 5000
}

variable "task_cpu" {
  description = "CPU alocada para a task Fargate (unidades de CPU)"
  type        = string
  default     = "256" # 0.25 vCPU, mínimo do Fargate
}

variable "task_memory" {
  description = "Memória alocada para a task Fargate (MB)"
  type        = string
  default     = "512" # mínimo compatível com 0.25 vCPU
}
