$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_fs/version'

Gem::Specification.new do |s|
  s.name = "knife-install"
  s.version = "0.0.1" 
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc" ]
  s.summary = "Universal knife verbs like  install  which  short circuits  and  the   chef  server  client  mechanisms "
  s.description = s.summary
  s.author = "Pratik  Dam"
  s.email = "pdam.2010@gmail.com"
  s.homepage = "http://www.limepeper.co.uk"

  s.require_path = 'lib'
  s.files = %w( README.rdoc Rakefile) + Dir.glob("{lib,spec}/**/*")
end

