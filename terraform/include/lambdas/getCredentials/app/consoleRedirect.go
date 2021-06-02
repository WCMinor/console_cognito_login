package app

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go/aws"
	identityPool "github.com/aws/aws-sdk-go/service/cognitoidentity"
)

// ConsoleRedirect populates the Console Login redirect URL
func (a *App) ConsoleRedirect(r events.APIGatewayV2HTTPRequest) {
	//The Cognito UI will give us a Code Grant string after a successful login
	codeGrant := string(r.QueryStringParameters["code"])
	if codeGrant == "" {
		panic(fmt.Errorf("empty code returned from identity provider"))
	}
	//We need to exchange the Code Grant for a JWT token
	tokenURL := fmt.Sprintf("https://%s.auth.%s.amazoncognito.com/oauth2/token", a.UserPoolDomain, a.AWSRegion)
	cognitoURL := fmt.Sprintf("cognito-idp.%s.amazonaws.com/%s", a.AWSRegion, a.UserPoolID)
	HTTPClient := &http.Client{}
	v := url.Values{}
	v.Set("grant_type", "authorization_code")
	v.Set("client_id", a.AppClientID)
	v.Set("code", codeGrant)
	v.Set("redirect_uri", a.UserPoolRedirectURL)
	//Set the request
	tokenRequest, err := http.NewRequest("POST", tokenURL, strings.NewReader(v.Encode()))
	if err != nil {
		log.Printf("could not create request from token auth URL: %s", err.Error())
	}
	tokenRequest.SetBasicAuth(a.AppClientID, a.AppClientSecret)
	tokenRequest.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	//Do the call to Cognito to get the JWT token
	tokenResponse, err := HTTPClient.Do(tokenRequest)
	if err != nil {
		log.Printf("\ncould not get response from token auth URL: %s", err.Error())
	}
	bodyText, err := ioutil.ReadAll(tokenResponse.Body)
	if err != nil {
		log.Printf("\ncould not read response body: %s", err.Error())
	}
	//Token holds the JWT Cognito tokens
	type Token struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		IdToken      string `json:"id_token"`
		TokenType    string `json:"token_type"`
		ExpiresIn    string `json:"expires_in"`
	}

	var token Token
	json.Unmarshal(bodyText, &token)
	if token.IdToken == "" {
		log.Printf("\nempty token\n Token request response: %s", bodyText)
	}

	//Get identity object from Cognito Identyty Pool with the Id Token
	identity, err := a.IdentityPoolClient.GetId(&identityPool.GetIdInput{
		IdentityPoolId: aws.String(a.IdentityPoolID),
		Logins:         map[string]*string{cognitoURL: &token.IdToken},
	})
	if err != nil {
		log.Printf("\ncould not get identity id: %s", err.Error())
	}

	//Get STS credentials from Identity Pool with the identity object and the Id Token
	getCredsInput := &identityPool.GetCredentialsForIdentityInput{
		Logins:     map[string]*string{cognitoURL: &token.IdToken},
		IdentityId: identity.IdentityId,
	}
	stsToken, err := a.IdentityPoolClient.GetCredentialsForIdentity(getCredsInput)
	if err != nil {
		log.Printf("\ncould not generate STS token from auth code grant: %s", err.Error())
	}

	//Populate the STS session token
	var sessionToken SessionToken
	sessionToken.SessionId = *stsToken.Credentials.AccessKeyId
	sessionToken.SessionKey = *stsToken.Credentials.SecretKey
	sessionToken.SessionToken = *stsToken.Credentials.SessionToken

	sessionTokenJson, _ := json.Marshal(sessionToken)

	//Get the sigin token from the AWS federation API
	signinToken, err := constructSigningToken(sessionTokenJson)
	if err != nil {
		panic(err)
	}
	//Get the login URL and pass it back without calling it
	loginURL, err := getLoginURL(signinToken, cognitoURL)
	if err != nil {
		panic(err)
	}
	// populate the console redirection URL redirection
	a.LoginRedirectURL = loginURL
}
