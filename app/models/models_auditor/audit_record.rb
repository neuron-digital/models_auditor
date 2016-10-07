module ModelsAuditor
  class AuditRecord < ActiveRecord::Base
    ACTION_CREATE  = 0
    ACTION_UPDATE  = 1
    ACTION_DESTROY = 2
    begin
      establish_connection [ModelsAuditor.config.connection_namespace, Rails.env].map(&:presence).compact.join('_').to_sym
    rescue StandardError
      # ignored
    end

    self.table_name = ModelsAuditor.config.audit_records_table_name

    belongs_to :request, class_name: ModelsAuditor::AuditRequest.name, foreign_key: :request_id
    belongs_to :auditable, polymorphic: true, foreign_key: :object_id, foreign_type: :object_type

    enum action: {action_create: ACTION_CREATE, action_update: ACTION_UPDATE, action_destroy: ACTION_DESTROY}

    validates :object_type, :object_id, presence: true
  end
end
