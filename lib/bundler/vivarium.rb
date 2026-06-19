# frozen_string_literal: true

require_relative "vivarium/version"

module Bundler
  # Bundler plugin that audits `bundle install` behavior using the Vivarium
  # security observation library. It hooks into Bundler's install lifecycle and
  # starts a Vivarium observation session so that any low-level activity (file
  # access, process exec, network connections, etc.) triggered while resolving
  # and installing gems is recorded and reported.
  module Vivarium
    class Error < StandardError; end

    # Set to a truthy value to silence the plugin entirely.
    DISABLE_ENV = "BUNDLER_VIVARIUM_DISABLE"

    # Comma-separated list of event names to display (e.g. "path_open,sock_connect").
    # When unset, every event type is shown (subject to the path_open default below).
    EVENTS_ENV = "BUNDLER_VIVARIUM_EVENTS"

    # By default `path_open` is very noisy during an install, so it is limited to
    # files under these prefixes unless the user opts into more via EVENTS_ENV.
    PATH_OPEN_DEFAULT_PREFIXES = %w[/etc /proc].freeze

    class << self
      # Registers the Bundler hook. Called from the gem's plugins.rb when the
      # plugin is loaded by Bundler.
      def register_hooks!
        Bundler::Plugin::API.hook(Bundler::Plugin::Events::GEM_BEFORE_INSTALL_ALL) do |dependencies|
          Bundler::Vivarium.start_observation(dependencies)
        end
      end

      # Starts a top-level Vivarium observation session before gems are
      # installed. The session keeps observing for the lifetime of the Bundler
      # process and renders its report at exit, so the whole install is audited.
      #
      # Failures here must never break `bundle install`, so every error is caught
      # and surfaced as a warning instead.
      def start_observation(dependencies)
        return if disabled?

        require "vivarium"

        filter = build_filter
        announce(dependencies, filter)
        @session = ::Vivarium.observe(filter: filter)
      rescue LoadError => e
        warn_ui("vivarium library is not available, skipping audit: #{e.message}")
        nil
      rescue StandardError => e
        warn_ui("failed to start audit: #{e.class}: #{e.message}")
        nil
      end

      private

      def disabled?
        value = ENV[DISABLE_ENV]
        value && !value.empty? && value != "0" && value.downcase != "false"
      end

      # Builds the Vivarium display filter. `path_open` is always limited to the
      # default prefixes; other events are shown unless EVENTS_ENV narrows the set.
      def build_filter
        filter = { payload: { "path_open" => path_open_default_pattern } }
        events = parse_events(ENV[EVENTS_ENV])
        filter[:events] = events unless events.empty?
        filter
      end

      def parse_events(raw)
        return [] if raw.nil?

        raw.split(",").map(&:strip).reject(&:empty?)
      end

      # `path_open` targets are rendered via String#inspect (e.g. "/etc/passwd"),
      # so allow an optional leading quote and require one of the prefixes at the
      # start of the path.
      def path_open_default_pattern
        alternation = PATH_OPEN_DEFAULT_PREFIXES.map { |p| Regexp.escape(p) }.join("|")
        %r{\A"?(?:#{alternation})(?:/|"|\z)}
      end

      def announce(dependencies, filter)
        names = Array(dependencies).map { |dep| dep.respond_to?(:name) ? dep.name : dep.to_s }
        info_ui("auditing bundle install of #{names.size} gem(s) via Vivarium")
        info_ui("gems: #{names.sort.join(', ')}") unless names.empty?

        if filter[:events]
          info_ui("event filter: #{filter[:events].join(', ')}")
        else
          info_ui("event filter: all events (path_open limited to #{PATH_OPEN_DEFAULT_PREFIXES.join(', ')})")
        end
      end

      def info_ui(message)
        line = "[bundler-vivarium] #{message}"
        if defined?(Bundler) && Bundler.respond_to?(:ui) && Bundler.ui
          Bundler.ui.info(line)
        else
          warn(line)
        end
      end

      def warn_ui(message)
        line = "[bundler-vivarium] #{message}"
        if defined?(Bundler) && Bundler.respond_to?(:ui) && Bundler.ui
          Bundler.ui.warn(line)
        else
          warn(line)
        end
      end
    end
  end
end
