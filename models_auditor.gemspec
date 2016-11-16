$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'models_auditor/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'models_auditor'
  s.version     = ModelsAuditor::VERSION
  s.authors     = ['Alexander Gorbunov']
  s.email       = ['lexgorbunov@gmail.com']
  s.homepage    = 'https://github.com/Go-Promo/models_auditor'
  s.summary     = 'ModelsAuditor is an ORM extension that logs all changes to your models.'
  s.description = 'ModelsAuditor is an ORM extension that logs all changes to your models. Audited also allows you to record who made those changes, save associate models related to the changes.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'rails', '~> 4.0'
  s.add_dependency 'pg', '~> 0.18.4'
  s.add_dependency 'request_store', '~> 1.3.1'
  s.add_dependency 'sidekiq', '>= 2.17.7'

  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-nav'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end
