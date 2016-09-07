require 'request_store'
require 'json_api'
require 'models_auditor/engine'
require 'models_auditor/config'
require 'models_auditor/audit'
require 'models_auditor/controller'

module ModelsAuditor
  module_function
  def log_error(*args)
    if (logger = ModelsAuditor.config.logger)
      logger.error(*args)
    end
    puts *args
  end

  def log_info(*args)
    if (logger = ModelsAuditor.config.logger)
      logger.info(*args)
    end
    puts *args
  end

  def log_warn(*args)
    if (logger = ModelsAuditor.config.logger)
      logger.warn(*args)
    end
    puts *args
  end

  def store
    RequestStore.store[:models_auditor_store] ||= {}
  end
end

ActiveSupport.on_load(:active_record) do
  include ModelsAuditor::Audit
end
