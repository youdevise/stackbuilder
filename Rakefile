require 'ci/reporter/rake/rspec'
require 'rspec/core/rake_task'

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec => ['ci:setup:rspec']) do |_config|
  $options = {
    :verbose => 0
  }
end

desc 'Clean up the build directory'
task :clean do
  sh 'rm -rf build/'
end

desc 'Create a debian package'
task :package do
  version = "0.0.#{ENV['BUILD_NUMBER']}"

  sh 'rm -rf build/package'
  sh 'mkdir -p build/package/usr/local/lib/site_ruby/timgroup/'
  sh 'cp -r lib/* build/package/usr/local/lib/site_ruby/timgroup/'
  sh 'mkdir -p build/package/usr/lib/ruby/vendor_ruby/puppet/indirector/node/'
  sh 'cp lib/puppet/indirector/node/stacks.rb build/package/usr/lib/ruby/vendor_ruby/puppet/indirector/node/'

  sh 'mkdir -p build/package/usr/local/bin/'
  sh 'cp -r bin/* build/package/usr/local/bin/'

  arguments = [
    '--description', 'stackbuilder',
    '--url', 'https://github.com/tim-group/stackbuilder',
    '-p', "build/stackbuilder-transition_#{version}.deb",
    '-n', 'stackbuilder-transition',
    '-v', "#{version}",
    '-m', 'Infrastructure <infra@timgroup.com>',
    '-d', 'ruby-bundle',
    '-a', 'all',
    '-t', 'deb',
    '-s', 'dir',
    '-C', 'build/package'
  ]

  argv = arguments.map { |x| "'#{x}'" }.join(' ')
  sh 'rm -f build/*.deb'
  sh "fpm #{argv}"
end

desc 'Create a debian package'
task :install => [:package] do
  sh 'sudo dpkg -i *.deb'
  sh 'sudo /etc/init.d/mcollective restart;'
end

desc 'Generate CTags'
task :ctags do
  sh 'ctags -R --exclude=.git --exclude=build .'
end

desc 'Run lint (Rubocop)'
task :lint do
  sh 'rubocop'
end
