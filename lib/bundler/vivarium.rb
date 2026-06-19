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

        announce(dependencies)
        @session = ::Vivarium.observe
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

      def announce(dependencies)
        names = Array(dependencies).map { |dep| dep.respond_to?(:name) ? dep.name : dep.to_s }
        info_ui("auditing bundle install of #{names.size} gem(s) via Vivarium")
        info_ui("gems: #{names.sort.join(', ')}") unless names.empty?
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
