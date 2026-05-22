# ================================================================================
# DATA SOURCES
# Lê recursos que já existem na conta. Não cria nem modifica nada.
# Toda conta AWS vem com uma VPC padrão e subnets em cada AZ da região.
# ================================================================================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ================================================================================
# ECR (Elastic Container Registry)
# Repositório privado onde as imagens Docker ficam armazenadas.
# O pipeline faz push para cá; o ECS fará pull a partir daqui.
# ================================================================================
resource "aws_ecr_repository" "this" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE" # permite sobrescrever a tag :latest

  image_scanning_configuration {
    scan_on_push = true # escaneia vulnerabilidades a cada push
  }
}

# ================================================================================
# IAM - Execution Role
# O Fargate precisa de uma role para agir em nome da task:
#   - Puxar a imagem do ECR
#   - Escrever logs no CloudWatch
# Essa role é assumida pelo serviço ecs-tasks.amazonaws.com.
# ================================================================================
resource "aws_iam_role" "ecs_execution" {
  name = "${var.app_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Policy gerenciada pela AWS que cobre ECR pull + CloudWatch Logs
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ================================================================================
# CLOUDWATCH LOG GROUP
# Destino dos logs do container (stdout/stderr do gunicorn).
# retention_in_days evita acúmulo indefinido de logs (relevante no free tier).
# ================================================================================
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

# ================================================================================
# SECURITY GROUP
# Firewall da task. Sem load balancer, o tráfego chega direto ao container.
# ingress: aceita conexões na porta da aplicação de qualquer origem
# egress:  saída livre (necessário para o Fargate puxar imagem do ECR)
# ================================================================================
resource "aws_security_group" "ecs_task" {
  name        = "${var.app_name}-sg"
  description = "Permite trafego de entrada na porta da aplicacao e saida livre"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # aberto para demonstração; em produção real,
                                # restringir ao CIDR do load balancer ou VPN
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # todos os protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================================================================
# ECS CLUSTER
# Agrupamento lógico de tasks e serviços.
# Com Fargate, o cluster não gerencia servidores. A AWS cuida da infraestrutura.
# ================================================================================
resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-cluster"
}

# ================================================================================
# TASK DEFINITION
# Descreve o container: qual imagem rodar, quanto recurso alocar,
# quais portas expor e para onde mandar os logs.
# Fargate exige que cpu e memory sejam declarados na task, não no container.
# ================================================================================
resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # obrigatório no Fargate
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = var.app_name
    image     = "${aws_ecr_repository.this.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    # Instrui o ECS a verificar o health check antes de considerar a task healthy.
    # Espelha o HEALTHCHECK do Dockerfile, mas no nível do orquestrador.
    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.container_port}/health')\" || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ================================================================================
# ECS SERVICE
# Garante que uma task esteja sempre rodando.
# Se o container morrer ou ficar unhealthy, o ECS sobe um substituto.
#
# assign_public_ip = true: necessário sem NAT gateway (free tier).
# Sem IP público, o Fargate não consegue puxar a imagem do ECR.
# ================================================================================
resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = true
  }
}
