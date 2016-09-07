module ModelsAuditor
  class AuditRequest < ActiveRecord::Base
    establish_connection [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
    self.table_name = ModelsAuditor.config.audit_requests_table_name

    has_many :records, class_name: ModelsAuditor::AuditRecord.name, foreign_key: :request_id, inverse_of: :request

    # def as_json(options = nil)
    #   super({include: :records }.merge(options || {}))
    # end
  end
end
