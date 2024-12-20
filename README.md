# GitHub CLI Wrapper

## Introduction
This repository provides a Bash script wrapper for the GitHub CLI (`gh`) to streamline operations in a Dockerized environment. The script simplifies workflows by eliminating the need to manually install and configure the `gh` CLI on your local machine.

## Key Features
- **Secrets Management**: Easily set and manage repository secrets from files, stdin, or environment variables.
- **Containerized Execution**: Run all GitHub CLI commands inside a Docker container for isolation and simplicity.
- **Minimal Local Setup**: No need to install the GitHub CLI or manage dependencies locally.

## Requirements
- [Docker](https://www.docker.com/) installed and running on your system.

## Installation

### Clone the Repository
```bash
git clone https://github.com/your-username/github-cli-wrapper.git
cd github-cli-wrapper
```

### Copy the Wrapper Script
Copy the wrapper script (`gh.sh`) to a any directory:
```bash
cp gh.sh ~/gh.sh
```

## Usage

### Running the Wrapper Script
The wrapper script (`gh.sh`) simplifies the execution of `gh` commands within the Docker container. Below are common usage patterns:

#### Setting Repository Secrets

1. **From stdin:**
   ```bash
   ~/gh.sh -r my-repo --env-stdin <<< "SECRET_KEY=my-secret-value"
   ```

2. **From a file:**
   ```bash
   ~/gh.sh -r my-repo --env-file /path/to/secrets.env
   ```

3. **Direct variable assignment:**
   ```bash
   ~/gh.sh -r my-repo -e API_TOKEN=abc123 -e DB_PASSWORD=secret123
   ```

#### Running Scripts

1. **From a file:**
   ```bash
   ~/gh.sh -f /path/to/script.sh
   ```

2. **From stdin:**
   ```bash
   ~/gh.sh --stdin << EOF
   echo "Hello from stdin script!"
   EOF
   ```

#### Interactive Use
Running the script without arguments launches an interactive session:
```bash
~/gh.sh
```

### Credentials Storage
The script automatically stores GitHub CLI credentials in a `gh` folder located in the same directory as the script. Ensure that this folder is secure and accessible only by authorized users.

## Cleanup
To remove unused Docker images or resources, you can clean up using standard Docker commands:
```bash
docker image prune -f
# Also remove the gh folder containing credentials
rm -rf ~/gh
```

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request.

## Acknowledgments
- [GitHub CLI](https://cli.github.com/)
- [Docker](https://www.docker.com/)
