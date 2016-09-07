# desc "Explaining what the task does"
# task :models_auditor do
#   # Task goes here
# end
namespace :db do
  namespace :audit do
    task :connect_without_db, [:database] => [:environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?

      connection_params =
        ActiveRecord::Base.configurations[db].merge(
          'database'           => 'postgres',
          'schema_search_path' => 'public'
        )
      ActiveRecord::Base.establish_connection(connection_params)
    end

    task :connect, [:database] => [:environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?

      connection_params = ActiveRecord::Base.configurations[db]
      ActiveRecord::Base.establish_connection(connection_params)
    end

    desc 'Create the audit db in custom database specified in databases.yml'
    task :create, [:database] => [:connect_without_db, :environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?
      database_name = ActiveRecord::Base.configurations[db]['database']

      puts "Applying create on #{db}"
      ActiveRecord::Base.connection.create_database(database_name)
    end

    desc 'Drop the audit db specified in databases.yml'
    task :drop, [:database] => [:connect_without_db, :environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?
      database_name = ActiveRecord::Base.configurations[db]['database']

      # Дропаем существующие подключения
      # и запрещаем новые на время пересоздания базы
      ActiveRecord::Base.connection.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{database_name}';")
      ActiveRecord::Base.connection.execute("UPDATE pg_database SET datallowconn = 'false' WHERE datname = '#{database_name}';")
      begin
        puts "Applying drop on #{db}"
        ActiveRecord::Base.connection.drop_database(database_name)
      ensure
        ActiveRecord::Base.connection.execute("UPDATE pg_database SET datallowconn = 'true' WHERE datname = '#{database_name}';")
      end
    end

    desc 'Migrate the audit database (options: VERSION=x).'
    task :migrate, [:database] => [:connect, :environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?

      migrations_dir = Rails.root.join('db', ModelsAuditor.config.audit_migrations_dir).to_s
      ActiveRecord::Migration.verbose = true
      ActiveRecord::Migrator.migrate(migrations_dir, ENV['VERSION'] ? ENV['VERSION'].to_i : nil)
    end

    desc 'Rolls the schema of the audit database back to the previous version (specify steps w/ STEP=n).'
    task :rollback, [:database] => [:connect, :environment] do |t, args|
      db = args.database || [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
      raise ArgumentError.new('Required parameter [<database>] was not passed') if db.blank?

      migrations_dir = Rails.root.join('db', ModelsAuditor.config.audit_migrations_dir).to_s
      step = ENV['STEP'] ? ENV['STEP'].to_i : 1
      ActiveRecord::Migrator.rollback(migrations_dir, step)
    end
  end
end