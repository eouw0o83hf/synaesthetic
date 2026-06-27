fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios sync_dev_signing

```sh
[bundle exec] fastlane ios sync_dev_signing
```

Sync development code signing

### ios sync_release_signing

```sh
[bundle exec] fastlane ios sync_release_signing
```

Sync App Store code signing

### ios test

```sh
[bundle exec] fastlane ios test
```

Run all unit and UI tests

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and submit to App Store

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate App Store screenshots

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots to App Store Connect (no binary upload)

### ios fetch_dsyms

```sh
[bundle exec] fastlane ios fetch_dsyms
```

Download dSYMs for crash symbolication

### ios rotate_certs

```sh
[bundle exec] fastlane ios rotate_certs
```

Rotate match certificates (if compromised)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
