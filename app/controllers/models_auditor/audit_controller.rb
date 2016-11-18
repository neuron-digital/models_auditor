module ModelsAuditor
  class AuditController < ModelsAuditor.config.audit_controller_base.classify.constantize
    layout 'models_auditor/application'

    # GET /pages.json
    def index
      page          = params.fetch(:page, 1).to_i
      per_page      = ModelsAuditor.config.records_per_page
      paginate_info = {page: page, per_page: per_page}.tap do |info|
        info.merge!(total_entries: (page * per_page + per_page * 10)) if ModelsAuditor.config.fake_total_count
      end

      @collection =
        ModelsAuditor::AuditRequest.includes(:records).all
          .order("#{ModelsAuditor::AuditRequest.table_name}.created_at DESC")
          .paginate(paginate_info)

      @collection = apply_filters(@collection, params[:filters])

      respond_to do |f|
        if ModelsAuditor.config.respond_to_json_enabled
          formatter = ModelsAuditor.config.log_output_formatter.constantize.new(@collection)

          f.json {
            render json: {
              ModelsAuditor.config.json_response_data_key => formatter.as_json,
              ModelsAuditor.config.json_response_meta_key => {
                per_page: @collection.per_page,
                total: @collection.total_entries,
                sort_by: @collection.order_info
              }
            }
          }
        end
        if ModelsAuditor.config.respond_to_html_enabled
          f.html
        end
      end
    end

    private

    def apply_filters(collection, filters)
      return collection if filters.blank? || collection.nil?
      original = collection
      if filters[:since_at].present? && (time = (Time.parse(filters[:since_at]) rescue nil)).present?
        collection =
          collection
            .includes(:records)
            .where(ModelsAuditor::AuditRecord.arel_table[:created_at].gteq(time))
            .references(ModelsAuditor::AuditRecord.table_name.to_sym)
      end
      if filters[:before_at].present? && (time = (Time.parse(filters[:before_at]) rescue nil)).present?
        collection =
          collection
            .includes(:records)
            .where(ModelsAuditor::AuditRecord.arel_table[:created_at].lteq(time))
            .references(ModelsAuditor::AuditRecord.table_name.to_sym)
      end
      if filters[:action].present?
        collection = collection.includes(:records).where(ModelsAuditor::AuditRecord.arel_table[:action].eq(ModelsAuditor::AuditRecord.actions[filters[:action]])).references(ModelsAuditor::AuditRecord.table_name.to_sym)
      end
      if filters[:user_id].present?
        collection = collection.where(user_id: filters[:user_id])
      end
      if filters[:object].present?
        cond = {}
        if (object_id = filters[:object][:id].to_i) > 0
          cond[:object_id] = object_id
        end
        if (object_type = filters[:object][:type]).present?
          cond[:object_type] = object_type
        end

        collection = collection.includes(:records).where(ModelsAuditor::AuditRecord.table_name.to_sym => cond)
      end

      filtered_requests = collection.pluck(:id)
      original.where(id: filtered_requests)
    end

  end
end
