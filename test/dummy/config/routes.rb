Rails.application.routes.draw do

  mount ModelsAuditor::Engine => '/models_auditor'
end
