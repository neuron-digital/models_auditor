# encoding: UTF-8
module ModelsAuditor
  class DbConfigGenerator < Rails::Generators::Base
    def add_db_config
      if (nmsps = ModelsAuditor.config.connection_namespace).present?
        inject_into_file 'config/database.yml', before: /\z/ do
          "\n#{nmsps}_development: &#{nmsps}_development\n" +
            "  adapter:    postgresql\n" +
            "  encoding:   unicode\n" +
            "  database:   audit_database\n" +
            "  pool:       5\n" +
            "  host:       localhost\n" +
            "  username:   audit_user\n" +
            "  password:   \n" +
            "#{nmsps}_production:     *#{nmsps}_development\n" +
            "#{nmsps}_staging:        *#{nmsps}_development\n" +
            "#{nmsps}_test:           *#{nmsps}_development\n"
        end
      end
    end

  end
end