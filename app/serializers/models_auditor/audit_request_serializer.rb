module ModelsAuditor
  class AuditRequestSerializer < JSONApi::ObjectSerializerDefinition
    attributes :id, :user_id, :request_info
  end
end