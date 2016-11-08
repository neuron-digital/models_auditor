module ModelsAuditor
  module Controller
    def self.included(base)
      base.before_action :set_models_auditor_request_params
    end

    protected

    def set_models_auditor_request_params
      ModelsAuditor.store[:audit_request] =
        ModelsAuditor::AuditRequest.new(
          user_id:      user_for_models_auditor,
          request_info: info_for_models_auditor
        )
    rescue StandardError
      # ignored
    end

    # Returns the user who is responsible for any changes that occur.
    # By default this calls `current_user` or `current_employee` and returns the result.
    #
    # Override this method in your controller to call a different
    # method, e.g. `current_person`, or anything you like.
    def user_for_models_auditor
      user =
        case
          when defined?(current_user)
            current_user
          when defined?(current_employee)
            current_employee
          else
            return
        end
      ActiveSupport::VERSION::MAJOR >= 4 ? user.try!(:id) : user.try(:id)
    rescue NoMethodError
      user
    end

    # Returns any information about the controller or request that you
    # want ModelsAuditor to store alongside any changes that occur.  By
    # default this returns an empty hash.
    #
    # Override this method in your controller to return a hash of any
    # information you need.  The hash's keys must correspond to columns
    # in your `auditor_requests` table, so don't forget to add any new columns
    # you need.
    #
    # For example:
    #
    #     {:ip => request.remote_ip, :user_agent => request.user_agent}
    #
    # The columns `ip` and `user_agent` must exist in your `versions` # table.
    #
    # Use the `:meta` option to `PaperTrail::Model::ClassMethods.has_paper_trail`
    # to store any extra model-level data you need.
    def info_for_models_auditor
      {
        ip:         request.remote_ip,
        user_agent: request.user_agent,
        controller: self.class.name,
        action:     action_name,
        path:       request.path_info
      }
    end
  end

  if defined?(::ActionController)
    ::ActiveSupport.on_load(:action_controller) { include ModelsAuditor::Controller }
  end
end
