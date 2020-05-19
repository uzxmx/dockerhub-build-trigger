package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"

	"github.com/Masterminds/semver"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/uzxmx/dockerhub-build-trigger/dockerhub"
)

type wrappedVersion struct {
	*semver.Version
	OriginalVersion string
}

type wrappedVersions []*wrappedVersion

func (s wrappedVersions) Len() int {
	return len(s)
}

func (s wrappedVersions) Less(i, j int) bool {
	return s[i].LessThan(s[j].Version)
}

func (s wrappedVersions) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

// getVersions gets an array of versions either from stdin or arguments.
func getVersions(readFromStdin bool, args []string) []string {
	var versions []string
	if readFromStdin {
		reader := bufio.NewReader(os.Stdin)
		for {
			line, err := reader.ReadString('\n')
			line = strings.Trim(line, " \t\r\n")
			if line != "" {
				versions = append(versions, strings.Split(line, " ")...)
			}
			if err == io.EOF {
				break
			} else if err != nil {
				log.Errorf("Failed to read from stdin: %v", err)
				panic(err)
			}
		}
	} else {
		versions = args
	}
	return versions
}

// parseVersions parses an array of versions with string format to
// semver.Version format.
func parseVersions(versions []string) (parsed []*wrappedVersion) {
	for _, version := range versions {
		v, err := semver.NewVersion(version)
		if err != nil {
			log.Errorf("Failed to parse version: %v (%s)", err, version)
		} else {
			parsed = append(parsed, &wrappedVersion{v, version})
		}
	}
	return
}

// findMaxN finds the max n versions from an array of versions.
func findMaxN(versions []string, n int) (maxn []*wrappedVersion) {
	if len(versions) == 0 {
		return
	}

	parsed := parseVersions(versions)
	sort.Sort(sort.Reverse(wrappedVersions(parsed)))
	return parsed[:n]
}

// findAllGreaterThan finds all versions which are greater than the
// target version.
func findAllGreaterThan(versions []string, target string, sorting bool) (result []*wrappedVersion) {
	parsed := parseVersions(versions)
	t, err := semver.NewVersion(target)
	if err != nil {
		log.Errorf("Failed to parse version: %v", err)
	}
	for _, v := range parsed {
		if v.GreaterThan(t) {
			result = append(result, v)
		}
	}
	if sorting {
		sort.Sort(sort.Reverse(wrappedVersions(result)))
	}
	return
}

func createRepos(user string, names []string) error {
	m := make(map[string]bool, len(names))
	for _, name := range names {
		m[name] = true
	}

	c, err := dockerhub.NewClient()
	if err != nil {
		log.Errorf("Failed to create dockerhub client: %v", err)
	}
	c.EachRepository(user, func(repo *dockerhub.Repository) {
		if _, ok := m[repo.Name]; ok {
			delete(m, repo.Name)
		}
	})

	repo := &dockerhub.Repository{
		Owner:      "uzxmx",
		Namespace:  user,
		Private:    false,
		Privacy:    "public",
		Provider:   "github",
		Repository: "dockerhub-build-trigger",
		Registry:   "docker",
		BuildSettings: []dockerhub.BuildSetting{
			{
				Autobuild:    true,
				BuildContext: "/",
				Nocache:      false,
				Dockerfile:   "Dockerfile",
				SourceType:   "Tag",
				Tag:          "{\\1}",
			},
		},
	}
	for name := range m {
		repo.Name = name
		repo.Image = user + "/" + name
		setting := &repo.BuildSettings[0]
		setting.SourceName = "/^" + name + "\\/(.+)$/"

		if err := c.CreateRepository(repo); err != nil {
			return err
		}
	}

	return nil
}

func main() {
	var (
		targetVersion   string
		readFromStdin   bool
		sorting         bool
		numberOfMaximum int
		user            string
	)

	rootCmd := &cobra.Command{Use: "utils"}
	cmd := &cobra.Command{
		Use:   "max",
		Short: "Find the max n versions from a list of versions",
		Run: func(cmd *cobra.Command, args []string) {
			if maxn := findMaxN(getVersions(readFromStdin, args), numberOfMaximum); len(maxn) != 0 {
				for _, v := range maxn {
					fmt.Println(v.OriginalVersion)
				}
			}
		},
	}
	flags := cmd.Flags()
	flags.BoolVar(&readFromStdin, "from-stdin", false, "Whether to read from stdin")
	flags.IntVarP(&numberOfMaximum, "number", "n", 1, "Return first n results")
	rootCmd.AddCommand(cmd)

	cmd = &cobra.Command{
		Use:   "gt",
		Short: "Find all versions which are greater than the specified version",
		Run: func(cmd *cobra.Command, args []string) {
			versions := findAllGreaterThan(getVersions(readFromStdin, args), targetVersion, sorting)
			for _, v := range versions {
				fmt.Println(v.OriginalVersion)
			}
		},
	}
	flags = cmd.Flags()
	flags.BoolVar(&readFromStdin, "from-stdin", false, "Whether to read from stdin")
	flags.BoolVarP(&sorting, "sort", "s", false, "Whether to sort the results (with DESCENDING order)")
	flags.StringVarP(&targetVersion, "target-version", "t", "", "Target version to compare")
	cmd.MarkFlagRequired("target-version")
	rootCmd.AddCommand(cmd)

	cmd = &cobra.Command{
		Use:   "create-repos",
		Short: "Create repositories in dockerhub",
		RunE: func(cmd *cobra.Command, args []string) error {
			return createRepos(user, args)
		},
	}
	flags = cmd.Flags()
	flags.StringVarP(&user, "user", "u", "", "Dockerhub user")
	rootCmd.AddCommand(cmd)

	if err := rootCmd.Execute(); err != nil {
		log.Error(err)
		os.Exit(1)
	}
}
