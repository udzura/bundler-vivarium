# frozen_string_literal: true

require_relative "lib/bundler/vivarium/version"

Gem::Specification.new do |spec|
  spec.name = "bundler-vivarium"
  spec.version = Bundler::Vivarium::VERSION
  spec.authors = ["Uchio Kondo"]
  spec.email = ["uchio.kondo@smarthr.co.jp"]

  spec.summary = "Bundler plugin that audits `bundle install` using Vivarium."
  spec.description = "A Bundler plugin that hooks into the gem install lifecycle " \
                     "and runs Vivarium observation so that file, process, and " \
                     "network activity during `bundle install` is audited."
  spec.homepage = "https://github.com/udzura/bundler-vivarium"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "vivarium", "~> 0.5.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
