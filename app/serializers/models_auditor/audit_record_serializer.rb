module ModelsAuditor
  class AuditRecordSerializer < JSONApi::ObjectSerializerDefinition
    attributes :id, :request_id, :action, :content, :object_type, :object_id, :created_at
  end
end
