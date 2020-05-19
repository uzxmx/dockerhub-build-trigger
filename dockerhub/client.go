package dockerhub

import (
	"net/http"

	resty "github.com/go-resty/resty/v2"
)

type Client struct {
	RestyClient *resty.Client
	authRetried bool
}

func NewClient() (*Client, error) {
	c := &Client{
		RestyClient: resty.New(),
	}
	err := c.initialize()
	return c, err
}

func (c *Client) initialize() error {
	client := c.RestyClient
	client.SetRedirectPolicy(resty.NoRedirectPolicy())
	client.SetRetryCount(2).AddRetryCondition(func(r *resty.Response, err error) bool {
		if status := r.StatusCode(); status != http.StatusUnauthorized && status != http.StatusForbidden {
			return false
		}

		if err := c.signIn(); err != nil {
			return false
		}

		return true
	})

	client.SetPreRequestHook(func(cl *resty.Client, r *http.Request) error {
		// When retrying a request, the header set on the resty.Request the first time will override
		// the header on the resty.Client, which may be updated before retrying, so we want to use
		// the updated header.
		if cl.Header.Get(headerCSRFToken) != r.Header.Get(headerCSRFToken) {
			r.Header.Set(headerCSRFToken, cl.Header.Get(headerCSRFToken))
		}
		return nil
	})

	tokens, err := readTokens()
	if err != nil {
		err = c.signIn()
		if err != nil {
			return err
		}
	} else {
		c.setTokens(tokens)
	}

	return nil
}
