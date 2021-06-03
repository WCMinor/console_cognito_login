# AWS console login via Cognito
AWS console login solution integrating Cognito with the Federation API

## Terraform

The solution is a Cognito configuration + a GatewayAPI API + a couple of AWS Lambda functions.

The whole solution infra is provided as IaC in Terraform templates.

## Lambda code

The Lambda code, written in Golang basically gets IAM STS temporary credentials from Cognito and generate
a passwordless login URL exchanging the STS credentials for a Signing token using the AWS Federation API.

Then it will return such URL to Gateway API so that our browser will be redirected to that URL, and that
will place us into an already logged in session.

There is an extra lambda function that I use to manipulate the `JWT` token and populate a special claim called `group`.

## Demo

There is a video presenting this code working [here](https://youtu.be/WsZdqm4QZ_o)
