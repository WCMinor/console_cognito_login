package app

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
)

//constructSigningToken calls the AWS Federation API and retrieves a Signing Token
func constructSigningToken(sessionTokenJson []byte) (string, error) {
	HTTPClient := &http.Client{}
	request_url := "https://signin.aws.amazon.com/federation"

	//Create the request
	loginTokenRequest, err := http.NewRequest("GET", request_url, nil)
	if err != nil {
		return "", fmt.Errorf("could not create request from token auth URL: %s", err.Error())
	}
	q := loginTokenRequest.URL.Query()
	q.Add("Action", "getSigninToken")
	q.Add("SessionDuration", "43200")
	//Pass the whole json object containing the STS credentials as a URL parameter
	q.Add("Session", string(sessionTokenJson))

	loginTokenRequest.URL.RawQuery = q.Encode()
	//Do the actual http call and get a response from the Federation API
	loginTokenResponse, err := HTTPClient.Do(loginTokenRequest)
	if err != nil {
		return "", fmt.Errorf("\ncould not get response from federation URL: %s", err.Error())
	}
	loginTokenBodyText, err := ioutil.ReadAll(loginTokenResponse.Body)
	if err != nil {
		return "", fmt.Errorf("\ncould not read response body: %s", err.Error())
	}
	//The response is a Json object containing a single field called SigningToken
	var loginToken struct {
		SigninToken string `json:"SigninToken"`
	}
	err = json.Unmarshal(loginTokenBodyText, &loginToken)
	if err != nil {
		return "", fmt.Errorf("parsing login token from federation URL: %s", err.Error())
	}

	//Return the Token as a string
	return loginToken.SigninToken, nil
}

//getLoginURL constructs a URL to call the Federation API using the Signing Token
//and returns the URL without calling it
func getLoginURL(token string, issuer string) (string, error) {
	request_url := "https://signin.aws.amazon.com/federation"

	//Create the request
	loginRequest, err := http.NewRequest("GET", request_url, nil)
	if err != nil {
		return "", fmt.Errorf("could not create request from token auth URL: %s", err.Error())
	}
	q := loginRequest.URL.Query()
	q.Add("Action", "login")
	q.Add("Issuer", issuer)
	q.Add("Destination", "https://console.aws.amazon.com/")
	//Add the Siging Token as a parameter
	q.Add("SigninToken", string(token))
	loginRequest.URL.RawQuery = q.Encode()

	//Return the Federation API URL without calling it
	return loginRequest.URL.String(), nil

}
