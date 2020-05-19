package dockerhub

import (
	"bufio"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
)

const headerCSRFToken = "X-CSRFToken"

type tokens struct {
	AuthToken string `json:"auth_token"`
	CSRFToken string `json:"csrf_token"`
}

var TokensFilePath = filepath.Join(os.Getenv("HOME"), ".dockerhub_tokens")

func (c *Client) signIn() error {
	username, password := os.Getenv("DOCKERHUB_USERNAME"), os.Getenv("DOCKERHUB_PASSWORD")
	client := c.RestyClient

	resp, _ := client.R().Get("https://hub.docker.com/sso/start?next=%2F?ref=login")
	resp, _ = client.R().Get(resp.Header().Get("Location"))

	parsedUrl, err := url.Parse(resp.Header().Get("Location"))
	if err != nil {
		return err
	}
	nextUrl := parsedUrl.Query().Get("next")

	resp, _ = client.R().SetBody(map[string]string{
		"username": username,
		"password": password,
	}).Post("https://id.docker.com/api/id/v1/user/login")

	resp, _ = client.R().Get("https://id.docker.com" + nextUrl)
	resp, _ = client.R().Get(resp.Header().Get("Location"))

	tokens := &tokens{}
	for _, cookie := range resp.Cookies() {
		switch cookie.Name {
		case "token":
			tokens.AuthToken = cookie.Value
		case "csrftoken":
			tokens.CSRFToken = cookie.Value
		}
	}

	c.setTokens(tokens)

	return saveTokens(tokens)
}

func (c *Client) setTokens(tokens *tokens) {
	c.RestyClient.SetCookies([]*http.Cookie{
		&http.Cookie{Name: "token", Value: tokens.AuthToken},
		&http.Cookie{Name: "csrftoken", Value: tokens.CSRFToken},
	}).SetHeader(headerCSRFToken, tokens.CSRFToken)
}

func openTokensFile() (*os.File, error) {
	file, err := os.OpenFile(TokensFilePath, os.O_RDWR, os.ModePerm)
	if os.IsNotExist(err) {
		file, err = os.Create(TokensFilePath)
		if err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}
	return file, nil
}

func saveTokens(tokens *tokens) error {
	file, err := openTokensFile()
	if err != nil {
		return err
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	data, err := json.Marshal(tokens)
	if err != nil {
		return err
	}
	_, err = writer.Write(data)
	if err != nil {
		return err
	}
	return writer.Flush()
}

func readTokens() (*tokens, error) {
	file, err := openTokensFile()
	if err != nil {
		return nil, err
	}
	defer file.Close()
	defer file.Close()

	data, err := ioutil.ReadAll(file)
	if err != nil {
		return nil, err
	}

	tokens := &tokens{}
	err = json.Unmarshal(data, tokens)
	if err != nil {
		return nil, err
	}

	return tokens, nil
}
