#!/usr/bin/env bash

set -e

# Usage/help function
function show_help() {
  cat <<EOF
Usage: gh.sh [OPTIONS] [SCRIPT_ARGS...]

Options:
  -f FILE_PATH                Run the script inside the container from FILE_PATH.
  --stdin                     Read the script content from stdin and run it in the container.
  -r, --repo                  REPO_NAME Set the repository name for the script.

Secrets options (requires -r, --repo option):
  -e, --env VAR=VAL           Set a secret with VAR=VAL.
  --env-file FILE_PATH        Set secrets from a file.
  --env-stdin                 Set secrets from stdin.

General options:
  -h, --help                  Show this help message and exit.
  -v, --verbose               Enable verbose mode (show script before running).
  -d, --dry-run               Show the script content and arguments without running the container.
  --                          Treat the rest of the arguments as script content.

If no options are provided and no arguments, just run the container.
If arguments are provided without -f or --stdin, treat them as script content.
EOF
}

# Variables
PARENT_DIRECTORY=$(dirname "$0")
CRED_DIRECTORY="$PARENT_DIRECTORY/gh"

is_verbose=false
is_file_path=false
file_path=""
is_stdin=false
is_dry_run=false

is_repo_set=false
repo_name=""
is_env_stdin=false
is_env_file=false
env_path=""
is_env_var=false
environment_vars=()

# Arrays for positional arguments after options
commands=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      is_verbose=true
      shift
      ;;
    -d|--dry-run)
      is_dry_run=true
      shift
      ;;
    -f)
      if [[ -z "$2" ]]; then
        echo "Error: $1 requires a file path argument." >&2
        exit 1
      fi
      is_file_path=true
      file_path="$2"
      shift 2
      ;;
    --stdin)
      is_stdin=true
      shift
      ;;
    -r|--repo)
      if [[ -z "$2" ]]; then
        echo "Error: $1 requires a repository name argument." >&2
        exit 1
      fi
      is_repo_set=true
      repo_name="$2"
      shift 2
      ;;
    --env-file)
      if [[ -z "$2" ]]; then
        echo "Error: $1 requires a file path argument." >&2
        exit 1
      fi
      is_env_file=true
      env_path="$2"
      shift 2
      ;;
    --env-stdin)
      is_env_stdin=true
      shift
      ;;
    -e|--env)
      if [[ -z "$2" ]]; then
        echo "Error: $1 requires a variable assignment argument." >&2
        exit 1
      fi
      is_env_var=true
      environment_vars+=("$2")
      shift
      ;;
    --)
      shift
      # The rest are considered commands or script content
      while [[ $# -gt 0 ]]; do
        commands+=("$1")
        shift
      done
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      commands+=("$1")
      shift
      ;;
  esac
done

# Functions

function run_container_interactive() {
  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Running container interactively (no arguments or scripts)."

  if [ $is_dry_run == true ]; then
    echo "Dry run enabled, not running the container."
    exit 0
  fi

  docker run \
     --rm \
     -it \
     --name gh \
     -v "$CRED_DIRECTORY:/root/.config/gh" \
     --entrypoint bash \
     ghcr.io/supportpal/github-gh-cli
}

function run_with_script_path() {
  local path="$1"
  shift
  local script_args=("$@")

  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Running script from file: $path"
  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Script arguments: ${script_args[*]}"
  [[ $is_verbose == true || $is_dry_run == true ]] && cat "$path"

  if [ $is_dry_run == true ]; then
    echo "Dry run enabled, not running the container."
    exit 0
  fi

  docker run \
     --rm --name gh \
     -v "$CRED_DIRECTORY:/root/.config/gh" \
     -v "$path:/root/tmp/bash.sh" \
     --entrypoint bash \
     ghcr.io/supportpal/github-gh-cli \
     -c "bash /root/tmp/bash.sh" "${script_args[@]}"
}

function run_with_script_from_stdin() {
  local script_args=("$@")
  local content
  content=$(cat)

  local script="#!/usr/bin/env bash
$content
"

  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Running script from stdin"
  [[ $is_verbose == true || $is_dry_run == true ]] && [[ ${#script_args[@]} -gt 0 ]] && echo "Script arguments: ${script_args[*]}"
  [[ $is_verbose == true || $is_dry_run == true ]] && echo "$script"

  if [ $is_dry_run == true ]; then
    echo "Dry run enabled, not running the container."
    exit 0
  fi

  docker run \
     --rm --name gh \
     -v "$CRED_DIRECTORY:/root/.config/gh" \
     --entrypoint bash \
     ghcr.io/supportpal/github-gh-cli \
     -c "echo \"$script\" > /root/tmp/bash.sh && bash /root/tmp/bash.sh" "${script_args[@]}"
}

function run_with_script() {
  local content=$1
  shift
  local script_args=("$@")

  local script="#!/usr/bin/env bash
$content
"

  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Running inline script"
  [[ $is_verbose == true || $is_dry_run == true ]] && [[ ${#script_args[@]} -gt 0 ]] && echo "Script arguments: ${script_args[*]}"
  [[ $is_verbose == true || $is_dry_run == true ]] && echo "$script"

  if [ $is_dry_run == true ]; then
    echo "Dry run enabled, not running the container."
    exit 0
  fi

  docker run \
     --rm --name gh \
     -v "$CRED_DIRECTORY:/root/.config/gh" \
     --entrypoint bash \
     ghcr.io/supportpal/github-gh-cli \
     -c "echo \"$script\" > /root/tmp/bash.sh && bash /root/tmp/bash.sh" "${script_args[@]}"
}

function run_with_set_variables() {
  local repo_name="$1"
  shift

  local input_method=""        # 'file', 'stdin', or 'args'
  local file_path=""
  local content=""

  # Parse arguments for this function
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        input_method="file"
        file_path="$2"
        shift 2
        ;;
      --stdin)
        input_method="stdin"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        # If we haven't chosen file or stdin, we're using arguments as VAR=VAL
        if [[ -z "$input_method" ]]; then
          input_method="args"
        fi
        # Put this back into a list to process later if needed
        set -- "$@"
        break
        ;;
    esac
  done

  # If still no input method, default to args if arguments remain
  if [[ -z "$input_method" && $# -gt 0 ]]; then
    input_method="args"
  fi

  # Acquire content based on input method
  case "$input_method" in
    file)
      if [[ ! -f "$file_path" ]]; then
        echo "Error: file '$file_path' not found."
        exit 1
      fi
      content=$(< "$file_path")
      ;;
    stdin)
      # If data is piped in, read it. Otherwise, error if no data is provided.
      if [[ ! -t 0 ]]; then
        content=$(cat)
      else
        echo "Error: No data provided via stdin."
        exit 1
      fi
      ;;
    args)
      # Interpret the remaining arguments as VAR=VAL pairs and build an .env file
      # Example: VAR1=val1 VAR2=val2 ...
      while [[ $# -gt 0 ]]; do
        env_variant="$1"
        shift
        # Validate format VAR=VAL
        if [[ "$env_variant" =~ ^[^=]+=[^=]+$ ]]; then
          content+="$env_variant"$'\n'
        else
          echo "Error: Argument '$env_variant' is not in VAR=VAL format."
          exit 1
        fi
      done
      ;;
    *)
      # If no input method determined and no arguments, error out
      if [[ -z "$input_method" ]]; then
        echo "Error: No content source provided."
        exit 1
      fi
      ;;
  esac

  # Verbose or dry-run mode print
  if [[ $is_verbose == true || $is_dry_run == true ]]; then
    case "$input_method" in
      file) echo "Setting secrets from file: $file_path" ;;
      stdin) echo "Setting secrets from stdin" ;;
      args) echo "Setting secrets from arguments" ;;
    esac
    echo -e "$content"
  fi

  # Run inside container:
  # Create a script that writes the content to .env and sets secrets
  run_with_script_from_stdin <<EOF
echo -e "$content" > ".env"
gh secret set -f ".env" -R "$repo_name"
EOF
}

#function run_with_set_variables() {
#  local env_variants=("$@")
#
#  local content=""
#
#  for env_variant in "${env_variants[@]}"; do
#    local env_var
#    local env_val
#    IFS='=' read -r env_var env_val <<< "$env_variant"
#
#    [[ $is_verbose == true || $is_dry_run == true ]] && echo "Setting secret: $env_var"
#
#    content+="gh secret set $env_var -b $env_val -R $repo_name\n"
#  done
#
#  run_with_script "$content"
#}

#function run_with_set_variables_from_stdin_or_file() {
#  local repo_name=$1
#  local maybe_file_path_stdin_or_content=$2
#  local content
#
#  if [[ -f "$maybe_file_path_stdin_or_content" ]]; then
#    content=$(cat "$maybe_file_path_stdin_or_content")
#  elif [[ -p /dev/stdin ]]; then
#    content=$(cat)
#  else
#    content=$maybe_file_path_stdin_or_content
#  fi
#
#  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Setting secrets from stdin or file"
#  [[ $is_verbose == true || $is_dry_run == true ]] && echo -e "$content"
#
#  run_with_script_from_stdin <<EOF
#echo -e "$content" > ".env"
#gh secret set -f ".env" -R $repo_name
#EOF
#}

#function run_with_set_variables_from_file() {
#  local repo_name=$1
#  local content
#  content=$(cat "$2")
#
#  [[ $is_verbose == true || $is_dry_run == true ]] && echo "Setting secrets from file: $2"
#  [[ $is_verbose == true || $is_dry_run == true ]] && echo -e "$content"
#
#  run_with_script_from_stdin <<EOF
#echo -e "$content" > ".env"
#gh secret set -f ".env" -R $repo_name
#EOF
#}

# Main logic

if $is_file_path; then
  # Run with a file path
  run_with_script_path "$file_path" "${commands[@]}"
elif $is_stdin; then
  # Run with stdin
  run_with_script_from_stdin "${commands[@]}"
elif $is_env_file; then
  if ! $is_repo_set; then
    echo "Error: -e requires -r or --repo option to be set." >&2
    exit 1
  fi
  run_with_set_variables "$repo_name" --file "$env_path"
elif $is_env_stdin; then
  if ! $is_repo_set; then
    echo "Error: --env-stdin requires -r or --repo option to be set." >&2
    exit 1
  fi
  run_with_set_variables "$repo_name" --stdin
elif $is_env_var; then
  if ! $is_repo_set; then
    echo "Error: --env requires -r or --repo option to be set." >&2
    exit 1
  fi
  # Run with environment variables
  run_with_set_variables "${environment_vars[@]}"
elif [[ ${#commands[@]} -gt 0 ]]; then
  # Run with provided script content as arguments
  run_with_script "${commands[@]}"
else
  # No arguments, just run container
  run_container_interactive
fi
