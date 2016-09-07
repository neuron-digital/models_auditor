module ModelsAuditor
  module MigrationsHelper
    extend  ActiveSupport::Concern

    included do
      include Rails::Generators::Migration

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end
    end

    def copy_migration(filename, destination)
      migrations_dir = File.join('db', ModelsAuditor.config.audit_migrations_dir)

      if self.class.migration_exists?(migrations_dir, "#{destination}.rb")
        say_status('skipped', "Migration #{destination}.rb already exists in #{migrations_dir}")
      else
        migration_template "#{filename}.rb.erb", File.join(migrations_dir, "#{destination}.rb")
      end
    end
  end
end
