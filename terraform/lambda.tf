resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "archive_file" "get_credentials_checksum" {
  type        = "zip"
  source_dir  = "include/lambdas/getCredentials"
  excludes    = ["main", "main.zip"]
  output_path = "/tmp/get_credentials_dir.zip"
}

resource "null_resource" "build_get_credentials" {
  triggers = {
    get_credentials_hash = "${data.archive_file.get_credentials_checksum.output_sha}"
  }

  provisioner "local-exec" {
    command = "docker run -e GOOS=linux -e GOARCH=amd64 -v ${abspath(path.module)}/include/lambdas/getCredentials:/app -w /app golang:1.16 go build -ldflags=\"-s -w\" -o main"
  }
}

data "archive_file" "get_credentials_zip" {
  depends_on = [
    null_resource.build_get_credentials
  ]
  type        = "zip"
  source_file = "include/lambdas/getCredentials/main"
  output_path = "include/lambdas/getCredentials/main.zip"
}


resource "aws_lambda_function" "get_credentials" {
  filename         = "include/lambdas/getCredentials/main.zip"
  function_name    = "${var.user_pool_name}-getCredentials"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "main"
  source_code_hash = data.archive_file.get_credentials_zip.output_base64sha256
  runtime          = "go1.x"

  environment {
    variables = {
      COGNITO_IDENTITY_POOL_ID       = aws_cognito_identity_pool.main.id,
      COGNITO_USER_POOL_ID           = aws_cognito_user_pool.pool.id,
      COGNITO_USER_POOL_REDIRECT_URL = "${aws_apigatewayv2_api.get_console.api_endpoint}/console",
      COGNITO_USER_POOL_DOMAIN       = aws_cognito_user_pool_domain.main.domain,
      COGNITO_APP_CLIENT_ID          = aws_cognito_user_pool_client.client.id,
      COGNITO_APP_CLIENT_SECRET      = aws_cognito_user_pool_client.client.client_secret
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_credentials.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.get_console.execution_arn}/*/*"
}

data "archive_file" "preToken" {
  type        = "zip"
  source_file = "include/lambdas/preToken/preToken.py"
  output_path = "include/lambdas/preToken/preToken.zip"
}


resource "aws_lambda_function" "pre_token_generation" {
  filename         = "include/lambdas/preToken/preToken.zip"
  function_name    = "${var.user_pool_name}-preToken"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "preToken.lambda_handler"
  source_code_hash = data.archive_file.preToken.output_base64sha256
  runtime          = "python3.8"
}

resource "aws_lambda_permission" "pre_token_generation" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_generation.arn
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}

data "archive_file" "postAuth" {
  type        = "zip"
  source_file = "include/lambdas/postAuth/postAuth.py"
  output_path = "include/lambdas/postAuth/postAuth.zip"
}

resource "aws_lambda_function" "post_authentication" {
  filename         = "include/lambdas/postAuth/postAuth.zip"
  function_name    = "${var.user_pool_name}-postAuth"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "postAuth.lambda_handler"
  source_code_hash = data.archive_file.postAuth.output_base64sha256
  runtime          = "python3.8"
}

resource "aws_lambda_permission" "post_authentication" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_authentication.arn
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}
