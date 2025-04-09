provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "dunviidy_lambda_transcription_exec_role" {
  name = "dunviidy_transcription_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "transcribe:StartTranscriptionJob" # Transcription Job
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.encoded_dump_bucket.arn}/*" # Input Bucket
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.template_output_bucket.arn}/*" # UPDATE THIS PORTION LATER DO NOT FORGET
      }
    ]
  })
  tags = {
    name  = "Dunviidy"
    Stage = "Test"
  }
}

resource "aws_iam_role_policy_attachment" "transcribe_lambda_custom" {
  role       = aws_iam_role.dunviidy_lambda_transcription_exec_role.name
  policy_arn = aws_iam_policy.lambda_transcribe_permissions.arn
}

# bucket where encoded videos are sent
resource "aws_s3_bucket" "encoded_dump_bucket" {
  bucket_prefix = "dunviidy-encoded-dump-bucket"
  force_destroy = true

  tags = {
    Name  = "Dunviidy"
    Stage = "Test"
  }
}

# this bucket only exist to test will be replaced with a randomly generated bucket later
resource "aws_s3_bucket" "template_output_bucket" {
  bucket_prefix = "dunviidy-template-bucket"
  force_destroy = true

  tags = {
    Name   = "Dunviidy"
    Stage  = "Test"
    Delete = "Later"
  }
}

data "archive_file" "lamba_function_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_srcs/lambda_function.py"
  output_path = "lambda_function.zip"
}

# generate a outline for a lambda function
resource "aws_lambda_function" "transcription_function" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = "dunviidy-transcription-job"
  handler          = "index.handler"
  role             = aws_iam_role.dunviidy_lambda_transcription_exec_role.arn
  runtime          = "python3.13"
  source_code_hash = data.archive_file.lamba_function_zip.output_base64sha256
  tags = {
    Name  = "Dunviidy"
    Stage = "Test"
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcription_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.encoded_dump_bucket.arn
}

resource "aws_s3_bucket_notification" "lambda_bucket_trigger" {
  bucket = aws_s3_bucket.encoded_dump_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.transcription_function.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}