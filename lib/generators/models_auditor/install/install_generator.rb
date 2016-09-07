# encoding: UTF-8
module ModelsAuditor
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    def descriptions
      @descriptions ||= YAML.load_file(File.expand_path('../../../../../config/config_option_descriptions.yml', __FILE__))
    end

    def copy_initializer
      template 'initializer.rb.erb', 'config/initializers/models_auditor.rb'
    end

    # def mount_routes
    #   [
    #     'Rails.application.routes.draw do',
    #     'Application.routes.draw do'
    #   ].each do |after_str|
    #     inject_into_file 'config/routes.rb', :after => after_str do
    #       "\n  mount GlobalStore::Engine, at: '/global_store'\n"
    #     end
    #   end
    # end
  end
end