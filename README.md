# LazyStern - Kubernetes Logs Helper

## Description

This is a Bash function designed to provide a simpler interface for querying logs from a Kubernetes cluster. The function is a wrapper around `stern`. I recommend learning `stern` instead of using this function. As this is a poorly implemented wrapper around `stern` for the lazy.

Please note this is simple helper and not fully featured.

It is designed to be a quick way to get logs from a Kubernetes cluster with an interactive interface. The interactive interface will fetch contexts and namespaces from which the user can select before running & will guide user through creating a time range from which to fetch logs.

The function will automatically detect the context namespace and kubernetes context if they are not provided. If you wish to query logs from a single pod. Please use `kubectl logs` instead.

Logs will be outputted as raw and can be piped into other commands like `awk`, `jq` or `yq` for further processing.

## Usage

```
Usage: lazystern [OPTIONS]
Options:
 -h, --help      Display this help message
 -i, --interactive  Enable interactive mode
 -s, --since     Display logs since the specified time (passed to stern)
	 Default: 48h, Format: [<num>m, <num>h] days, weeks, months & years are not valid
 -t, --to         Display logs until the specified time (used to filter logs with awk)
	 Format: ISO 8601, e.g. 2021-08-01T00:00:00.000Z
 -n, --namespace  Specify the kubernetes namespace to fetch logs from
 -c, --context    Specify the kubernetes context to fetch logs from
 -f, --follow     Follow logs
```

### ISO Helper

Wrapper around GNU date (coreutil)

```bash
# ISO Helper
# -d Option accepts
#  Modifiers relative to now in order to build ISO datetime
#   See GNU date coreutil relative items docs for syntax.
#   https://www.gnu.org/software/coreutils/manual/html_node/Relative-items-in-date-strings.html

#   Example: 
#   +1 day -4 hour -2 weeks +2 minutes +1 second
iso -d "-2 days"
```

### Please Note

Stern does not allow for collecting logs in a time window. Instead will get logs since a time. In order to This function will fetch all logs from the provided since time and then use `awk` to filter logs past the provided TO datetime.

## Examples


```bash
# with named options and full name
lazystern --namespace your-namespace --context your-context --since 1h --to $(iso -d "-30 minutes");
# using alias and short options for the lazy
lstern -n <namespace> -c <context> -s <stern since option> -t <DateTime ISO>;

# Run the interactive mode
lstern -i;
lstern --interactive;

# show pretty error logs
lstern -s 10m | grep 'error' | jq '.';

# show pretty logs from interactive mode
lstern -i | jq '.'
```

## Getting Started

### Dependencies

This function requires the following dependencies to be installed:

- `kubectl`
- `stern`
- `awk`
- `jq`

### Installing

To install the function:

- download it and add it to your `.bashrc`, `.bash_profile`, `.zshrc` or `.zsh_profile` file.

```bash
# Clone the repository
git clone --depth 1 https://github.com/NickMoignard/lazy-stern.git ~/.lazy-stern
# Source the file in your shell profile
# If you use zsh use .zshrc instead of .bashrc
echo "source ~/.lazy-stern/lazy-stern.sh" >> ~/.bashrc
```

#### Linux

This function makes use of `gdate` instead of `date`. If you are using linux please create a symlink to `gdate` as `date`.

```bash
sudo ln -s $(which date) /bin/gdate
```

## Contributing

Thank you for considering contributing to LazyStern! To contribute, please follow these guidelines:

1. Fork the repository and create a new branch.
2. Make your changes and test them thoroughly.
3. Commit your changes with a descriptive commit message.
4. Push your changes to your fork and submit a pull request.

Please ensure your code adheres to the existing code style and conventions.

## Issues

If you encounter any issues with LazyStern, please feel free to [open an issue](https://github.com/NickMoignard/lazy-stern/issues) on GitHub. I welcome bug reports, feature requests, and general feedback.

## License

LazyStern is open source software licensed under the MIT License. See the [LICENSE](https://github.com/NickMoignard/lazy-stern/blob/main/LICENSE) file for more information.
