package dockerhub

import (
	"errors"
	"fmt"
	"strconv"
)

type Repository struct {
	Owner         string         `json:"owner"`
	Name          string         `json:"name"`
	Namespace     string         `json:"namespace"`
	Private       bool           `json:"is_private"`
	Privacy       string         `json:"privacy"`
	Provider      string         `json:"provider"`
	Repository    string         `json:"repository"`
	Registry      string         `json:"registry"`
	Image         string         `json:"image"`
	BuildSettings []BuildSetting `json:"build_settings"`
}

type BuildSetting struct {
	Autobuild    bool   `json:"autobuild"`
	BuildContext string `json:"build_context"`
	Dockerfile   string `json:"dockerfile"`
	Nocache      bool   `json:"nocache"`
	SourceName   string `json:"source_name"`
	SourceType   string `json:"source_type"`
	Tag          string `json:"tag"`
}

type RepositoryList struct {
	Count    int          `json:"count"`
	Next     string       `json:"next"`
	Previous string       `json:"previous"`
	Results  []Repository `json:"results"`
}

func (c *Client) ListRepositories(user string, page, pageSize int) (*RepositoryList, error) {
	result := &RepositoryList{}

	_, err := c.RestyClient.R().SetResult(result).SetQueryParams(map[string]string{
		"page":      strconv.Itoa(page),
		"page_size": strconv.Itoa(pageSize),
	}).Get("https://hub.docker.com/v2/repositories/" + user + "/")

	if err != nil {
		return nil, err
	}

	return result, nil
}

func (c *Client) EachRepository(user string, cb func(*Repository)) error {
	if cb == nil {
		return errors.New("Callback function is required")
	}

	page, pageSize := 1, 2
	for {
		result, err := c.ListRepositories(user, page, pageSize)
		if err != nil {
			return err
		}
		if count := len(result.Results); count > 0 {
			for _, repo := range result.Results {
				cb(&repo)
			}

			if count < pageSize {
				return nil
			}
			page++
		} else {
			return nil
		}
	}
}

func (c *Client) CreateRepository(repo *Repository) error {
	resp, err := c.RestyClient.R().SetBody(repo).Post("https://hub.docker.com/v2/repositories/")
	if err != nil {
		return err
	}
	if !resp.IsSuccess() {
		return fmt.Errorf("Failed to create repository: %d %s", resp.StatusCode(), string(resp.Body()))
	}

	if err = c.UpdateBuildSettings(repo); err != nil {
		return err
	}

	return nil
}

func (c *Client) UpdateBuildSettings(repo *Repository) error {
	resp, err := c.RestyClient.R().SetBody(repo).Post("https://hub.docker.com/api/build/v1/" + repo.Owner + "/source/")
	if err != nil {
		return err
	}
	if !resp.IsSuccess() {
		return fmt.Errorf("Failed to update build settings: %d %s", resp.StatusCode(), string(resp.Body()))
	}

	return nil
}
