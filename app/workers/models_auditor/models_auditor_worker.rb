require 'sidekiq'

module ModelsAuditor
  class ModelsAuditorWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'models_auditor', retry: 2, backtrace: true

    def perform(request_data_json)
      return unless ModelsAuditor.config.audit_enabled

      ModelsAuditor::AuditRecord.connection.pool.with_connection do
        request_data = JSON.parse(request_data_json)
        request = ModelsAuditor::AuditRequest.new(request_data)
        unless request.save
          ModelsAuditor.log_error("Couldn't save request record")
          ModelsAuditor.log_error(request.errors.full_messages)
        end
      end
    end

  end
end
