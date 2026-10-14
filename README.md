# Copy Plugins

A Bash script that downloads the configured plugins for a release, extracts each archive, and copies its files to the configured destination directories.

## Requirements
It requires `bash`, `curl`, and `unzip`. The `staging` directory next to the script must exist and be writable. Each destination configured in `env` must also already exist and be writable.

## Configure

Edit the `env` file next to `copy-plugins.sh`. It is sourced as a Bash file, so use Bash assignment syntax. For example:

```bash
payment_plugin_destination="/mnt/c/plugins/payment"
comms_plugin_destination="/mnt/c/plugins/comms"
import_plugin_destination="/mnt/c/plugins/imports"

payment_plugins=("Adumo" "BarclaycardFuse" "Flywire" "GlobalPayments" "Moneris" "Pay360" "PayPal" "PayU" "SagePay" "SkipPayment" "Stripe" "TrustPayments" "WPM")
comms_plugins=("SMTP")
import_plugins=("Creatio")
```

The destinations must be existing directories. The arrays list the archive names to download; archive names and URL categories are configured in the script:

- Payment plugins are downloaded from `PaymentGateways/`.
- Comms plugins are downloaded from `Comms/`.
- Import plugins are downloaded from `Import/`.

## Usage

From WSL, in the directory containing the script:

```bash
./copy-plugins.sh 2.6.0-alpha.187
```

Add `-v` or `--verbose` to show curl's verbose output:

```bash
./copy-plugins.sh --verbose 2.6.0-alpha.187
```

The required version must be `major.minor.patch`, optionally followed by `-alpha.N`, `-beta.N`, or `-rc.N`. Numeric components cannot have leading zeroes, and the prerelease number must be between 0 and 999. Stable versions (without a prerelease suffix) use the `dc-web` download route. Prerelease versions below `2.5` use `dc-web-beta`; prerelease versions `2.5` and later use `dc-web-alpha`.

By default, the script prints one completion line per successful plugin. Failures are logged, processing continues for the remaining plugins, and the script exits with status 1 if any plugin failed.
