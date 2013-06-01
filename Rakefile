require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'aweplug/version'
require 'guard'

GEMFILE = "aweplug-#{Aweplug::VERSION}.gem"

task :default => :build

desc "Run all tests and build the gem"
task :build => 'test:spec' do
  system "gem build aweplug.gemspec"
end

desc "Build and install the gem locally"
task :install => :build do
  system "gem install -l -f #{GEMFILE}"
end

namespace :release do
  desc "Release the gem to rubygems"
  task :push => [ :build, :tag ] do
    system "gem push #{GEMFILE}"
  end

  desc "Create tag #{Aweplug::VERSION} in git"
  task :tag do
    system "git tag #{Aweplug::VERSION}"
  end
end

namespace :test do
  if !defined?(RSpec)
    puts "spec targets require RSpec"
  else
    desc "Run all specifications"
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = 'spec/**/*_spec.rb'
    end
  end

  desc "Start Guard to listen for changes and run specs"
  task :guard do
    Guard.start(:guardfile => 'Guardfile')
    Guard.run_all
    while ::Guard.running do
      sleep 0.5
    end
  end
end

