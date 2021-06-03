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

resource "aws_lambda_function" "get_credentials" {
  filename         = "include/lambdas/getCredentials/main.zip"
  function_name    = "${var.user_pool_name}-getCredentials"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "main"
  source_code_hash = filebase64sha256("include/lambdas/getCredentials/main.zip")
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
