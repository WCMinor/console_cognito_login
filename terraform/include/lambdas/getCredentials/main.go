package main

import (
	"fmt"
	"net/http"
	"os"

	"getCreds/app"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	identityPool "github.com/aws/aws-sdk-go/service/cognitoidentity"
)

// Call requests
func Call(a *app.App, r events.APIGatewayV2HTTPRequest) error {

	switch r.RawPath {
	case "/console":
		a.ConsoleRedirect(r)
	default:
		return fmt.Errorf("handler for path %s not found", r.RawPath)
	}
	return nil
}

//Lambda optimization: since this is an AWS Lambda function some things are "special":

//CognitoAdminClient carries all the information needed to speak to the Cognito API
var CognitoAdminClient app.App

//This function is executed only in cold starts, it is a good Lambda optimization
//practice to initialize info and store it in global variables so that it doesn't
//get executed on every handler call (every lambda call)
//All these environment variables must be added in the Lambda configuration
func init() {
	conf := &aws.Config{Region: aws.String(os.Getenv("AWS_REGION"))}
	sess, err := session.NewSession(conf)
	if err != nil {
		panic(err)
	}
	CognitoAdminClient = app.App{
		IdentityPoolClient:  identityPool.New(sess),
		AWSRegion:           os.Getenv("AWS_REGION"),
		UserPoolID:          os.Getenv("COGNITO_USER_POOL_ID"),
		UserPoolDomain:      os.Getenv("COGNITO_USER_POOL_DOMAIN"),
		UserPoolRedirectURL: os.Getenv("COGNITO_USER_POOL_REDIRECT_URL"),
		IdentityPoolID:      os.Getenv("COGNITO_IDENTITY_POOL_ID"),
		AppClientID:         os.Getenv("COGNITO_APP_CLIENT_ID"),
		AppClientSecret:     os.Getenv("COGNITO_APP_CLIENT_SECRET"),
	}
}

func HandleRequest(r events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	//Init empty ApiGateway response
	response := events.APIGatewayV2HTTPResponse{}

	err := Call(&CognitoAdminClient, r)
	if err != nil {
		return response, fmt.Errorf("calling Console Redirect: %s", err.Error())
	}

	//Set the response code to a redirect to the Federation API with the Signing Token
	//this redirection will authenticate our browser session and will do a further redirect
	//right into the AWS console, already logged in with a role assumed and no password promt
	response.StatusCode = http.StatusSeeOther
	response.Headers = make(map[string]string)
	response.Headers["Location"] = CognitoAdminClient.LoginRedirectURL
	//Return the APIGateway response to the Lambda handler
	return response, nil
}

func main() {
	//Just call the actual Lambda handler
	lambda.Start(HandleRequest)
}
