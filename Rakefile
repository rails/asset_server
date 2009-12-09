require 'rake/testtask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the asset_server plugin.'
Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end
