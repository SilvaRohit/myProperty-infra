resource "aws_ecr_repository" "property_app" {
  name = "${var.project_name}-${var.environment}"

  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

