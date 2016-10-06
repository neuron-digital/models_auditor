namespace :deploy do

  desc 'Runs rake db:audit:migrate if migrations are set'
  task :audit_migrate do
    on primary fetch(:migration_role) do
      info '[deploy:audit_migrate] Run `rake db:audit:migrate`'
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:audit:migrate'
        end
      end
    end
  end

  desc 'Runs rake db:audit:rollback'
  task :audit_rollback do
    on primary fetch(:migration_role) do
      info '[deploy:audit_rollback] Run `rake db:audit:rollback`'
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:audit:rollback'
        end
      end
    end
  end

  after 'deploy:migrate', 'deploy:audit_migrate'
end
