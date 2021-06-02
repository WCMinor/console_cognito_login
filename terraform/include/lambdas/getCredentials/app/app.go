package app

import (
	identityPool "github.com/aws/aws-sdk-go/service/cognitoidentity"
)

// App holds internals for auth flow.
type App struct {
	IdentityPoolClient  *identityPool.CognitoIdentity
	AWSRegion           string
	UserPoolID          string
	UserPoolDomain      string
	UserPoolRedirectURL string
	IdentityPoolID      string
	AppClientID         string
	AppClientSecret     string
	LoginRedirectURL    string
}

//SessionToken holds an AWS STS session token
type SessionToken struct {
	SessionId    string `json:"sessionId"`
	SessionKey   string `json:"sessionKey"`
	SessionToken string `json:"sessionToken"`
}
