# Bundler::Vivarium

A [Bundler](https://bundler.io/) plugin that audits the behavior of `bundle install` using the [Vivarium](https://github.com/udzura/vivarium) security observation library.

When installed, the plugin hooks into Bundler's install lifecycle (`GEM_BEFORE_INSTALL_ALL`) and starts a `Vivarium.observe` session before any gem is installed. Vivarium then records the low-level activity — file access, process exec, network connections, privilege changes, etc. — triggered while gems are resolved and installed, and prints a process-tree report when Bundler exits.

This makes it possible to spot suspicious behavior performed by gem install hooks or native extension builds during `bundle install`.

## Requirements

Vivarium relies on eBPF/LSM and a running `vivariumd` daemon, so the audit only works on a supported Linux host. See the [Vivarium README](https://github.com/udzura/vivarium) for daemon setup. On unsupported platforms the plugin degrades gracefully: it prints a warning and lets `bundle install` proceed normally.

## Installation

Install it as a Bundler plugin:

```bash
bundle plugin install bundler-vivarium
```

Or, while developing locally, point at the checkout:

```bash
bundle plugin install bundler-vivarium --git file:///path/to/bundler-vivarium --branch master
```

## Usage

1. Start the Vivarium daemon (root, on the Linux host):

   ```bash
   sudo bundle exec vivariumd --pin-dir /sys/fs/bpf/vivarium
   ```

2. Run `bundle install` as usual. With the plugin active you will see audit output like:

   ```
   [bundler-vivarium] auditing bundle install of 12 gem(s) via Vivarium
   [bundler-vivarium] gems: nokogiri, rack, ...
   ```

   and, on Bundler exit, the Vivarium process-tree report covering the install.

### Filtering events

By default every event type is reported, **except `path_open`, which is limited to files under `/etc` and `/proc`** to cut down on noise during installs.

To restrict the report to specific event types, set `BUNDLER_VIVARIUM_EVENTS` to a comma-separated list of event names:

```bash
# only show outgoing connections, DNS queries, and process execs
BUNDLER_VIVARIUM_EVENTS=sock_connect,dns_req,proc_exec bundle install
```

When `path_open` is included in the list, it is still limited to the `/etc` and `/proc` default. Event names match Vivarium's event names (`path_open`, `proc_exec`, `sock_connect`, `dns_req`, `file_symlink`, `capable_check`, etc.).

### Disabling

To temporarily disable the audit without removing the plugin, set:

```bash
BUNDLER_VIVARIUM_DISABLE=1 bundle install
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/udzura/bundler-vivarium. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/udzura/bundler-vivarium/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Bundler::Vivarium project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/udzura/bundler-vivarium/blob/master/CODE_OF_CONDUCT.md).
