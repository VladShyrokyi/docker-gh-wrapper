# GitHub CLI Docker Wrapper

## Introduction
This repository contains a Bash script wrapper for the GitHub CLI (`gh`), designed to simplify working with `gh` commands inside a Docker container. 

With this script, you can:
- Run `gh` commands without installing the CLI or its dependencies on your local system.
- Manage secrets securely (from files, stdin, etc.) with flexibility.
- Keep credentials isolated in a specific directory, such as your repository or home folder.
- Easily remove the environment by deleting the Docker container and image.

The script allows users to execute `gh` commands interactively or with custom scripts while handling the underlying Docker interactions automatically.
