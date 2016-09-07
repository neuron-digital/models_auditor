require 'rails/generators/base'
require 'generators/models_auditor/migrations_helper'

module ModelsAuditor
  class MigrationsGenerator < Rails::Generators::Base
    include MigrationsHelper
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_file
      @migration_postfix = SecureRandom.hex
      copy_migration 'create_audit_records', "create_audit_records_n#{@migration_postfix}"
      copy_migration 'create_audit_requests', "create_audit_requests_n#{@migration_postfix}"
    end
  end
end