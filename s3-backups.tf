resource "aws_s3_bucket" "property_backups" {
  bucket        = "tecerotech-property-147997138960-backups"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  depends_on = [aws_s3_bucket_versioning.property_backups]

  rule {
    id     = "expire-upload-backups"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "remove-expired-delete-markers"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}

resource "aws_s3_bucket_policy" "property_backups" {
  bucket = aws_s3_bucket.property_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "RequireHTTPS"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.property_backups.arn,
        "${aws_s3_bucket.property_backups.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}

#s3 bucket policy for the existing EC2 instance role to allow it to read and write backups to the S3 bucket.
resource "aws_iam_role_policy" "property_uploads_backup" {
  name = "property-app-uploads-backup"
  role = var.deployment_existing_ec2_role_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ReadBackupBucketLocation"
        Effect   = "Allow"
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.property_backups.arn
      },
      {
        Sid    = "ListUploadBackups"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = aws_s3_bucket.property_backups.arn

        Condition = {
          StringLike = {
            "s3:prefix" = ["uploads/*"]
          }
        }
      },
      {
        Sid    = "UploadAndRetrieveBackups"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:AbortMultipartUpload"
        ]
        Resource = "${aws_s3_bucket.property_backups.arn}/uploads/*"
      }
    ]
  })
}
