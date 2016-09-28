# ModelsAuditor

## Installation

1. **Add ModelsAuditor to your Gemfile**

    `gem 'models_auditor'`
    
    Then execute `$ bundle install`

2. **Add the gem settings to your project**

    `rails g models_auditor:install`

    It added _models_auditor_ initializer. Make necessary settings in this file.

3. **Generate the audit database config**

    `rails g models_auditor:db_config`

    It appended separate sections to config/database.yml. Edit them.

4. **Create the audit database**

    `rake db:audit:create`

5. **Generate models_auditor migrations for audit_database**

    `rails g models_auditor:migrations`

    Migration files will be putted into db/audit_migrate.

6. **Apply migrations to the audit database**

    `rake db:audit:migrate`

## Usages

1. Mount the route for read logs json api

    ```ruby
    Rails.application.routes.draw do
    
        mount ModelsAuditor::Engine => '/audit'
        
    end    
    ```
    
    To looking at routes list do
     
     `$ rake routes`
     
        models_auditor_requests GET  (/index)(/page/:page)(.:format) models_auditor/audit#index {:page=>/\d+/}
                           root GET  /                               models_auditor/audit#index

2. To enable audit you have to add into each logged models

    `enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON`
    
        AUDIT_MODE_JSON         - Serialization by #as_json
        AUDIT_MODE_SERIALIZER   - Serialization by using a ActiveModel Serializer, specifyied by :serializer option
        AUDIT_MODE_METHOD       - Serialization by a method, specifyied by :method option
        AUDIT_MODE_CHANGES_ONLY - Serialization ActiveRecord changes of model only
        
    ```ruby
    class Post < ActiveRecord::Base
      enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON
    end
    ```    
        
    ```ruby
    class Author < ActiveRecord::Base
      enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON
    end
    ```    
    
3. Add to each association models
    
    `enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON, bridge: {Author.name => :author_id, Post.name => :post_id}`
    
    ```ruby
    class AuthorsPost < ActiveRecord::Base
      enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON, bridge: {Author.name => :author_id, Post.name => :post_id}
    end
    ``` 

## Audit database management

**Creation of the audit database**

`rake db:audit:create`

**Dropping of the audit database**

`rake db:audit:drop`

**Apply migrations to the audit database**

`rake db:audit:migrate`

**Rollback migrations to the audit database**

`rake db:audit:rollback`

---

If you want to use a database prefix not from config. You may specify it as an argument in square brackets.

`rake db:audit:create[audit_shmaudit]`

## Capistrano

Add line to the Capfile

`require 'models_auditor/capistrano/rails/audit_migrations'`

**Migrate**

The capistrano migrate task

`cap deploy:audit_migrate`

will be executed automatically after `deploy:migrate` cap task 

**Rollback**

`cap deploy:audit_rollback`

This project rocks and uses MIT-LICENSE.
