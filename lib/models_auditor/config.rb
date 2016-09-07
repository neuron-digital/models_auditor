module ModelsAuditor
  class Config
    CONFIG_OPTIONS = %i(
      audit_enabled
      connection_namespace
      audit_records_table_name
      audit_requests_table_name
      audit_migrations_dir
      audit_request_changes_only
      logger
      records_per_page
      fake_total_count
      audit_controller_base
      respond_to_json_enabled
      respond_to_html_enabled
      json_response_data_key
      json_response_meta_key
    )

    def initialize
      @indexed_relations = []
    end

    def default
      @default ||= {
        audit_enabled:              {
          config: 'true',
          val:    true
        },
        connection_namespace:       {
          config: "'audit'",
          val:    'audit'
        },
        audit_records_table_name:   {
          config: "'audit_records'",
          val:    'audit_records'
        },
        audit_requests_table_name:  {
          config: "'audit_requests'",
          val:    'audit_requests'
        },
        audit_migrations_dir:       {
          config: "'audit_migrate'",
          val:    'audit_migrate'
        },
        logger:                     {
          config: "Logger.new(Rails.root.join('log', 'models_auditor.log'))",
          val:    Logger.new(Rails.root.join('log', 'models_auditor.log'))
        },
        audit_request_changes_only: {
          config: 'true',
          val:    true
        },
        records_per_page:           {
          config: '10',
          val:    10
        },
        fake_total_count:           {
          config: 'true',
          val:    true
        },
        audit_controller_base:      {
          config: "'ModelsAuditor::AuditBaseController'",
          val:    'ModelsAuditor::AuditBaseController'
        },
        respond_to_json_enabled:    {
          config: 'true',
          val:    true
        },
        respond_to_html_enabled:    {
          config: 'false',
          val:    false
        },
        json_response_data_key:     {
          config: "'entries'",
          val:    'entries'
        },
        json_response_meta_key:     {
          config: "'meta'",
          val:    'meta'
        },
      }
    end

    def method_missing(method_sym, *args)
      method_name = method_sym.to_s
      option_name = method_name.tr('=', '')
      super if CONFIG_OPTIONS.exclude?(option_name.to_sym)
      if method_name =~ /^.*=$/
        raise ArgumentError.new('Incorrect number of arguments') if args.size != 1
        instance_variable_set("@#{option_name}", args[0]) unless ModelsAuditor.configured?
      else
        var_name = "@#{option_name}"
        instance_variable_defined?(var_name) ?
          instance_variable_get(var_name) :
          default[option_name.to_sym].try(:[], :val)
      end
    end

  end

  module_function

  def configure(&block)
    Rails.application.config.after_initialize do
      block.call(config)
      @configured = true
    end
  end

  def configured?
    @configured
  end

  def config
    @config ||= Config.new
  end
end