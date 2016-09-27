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
          .paginate(paginate_info)

      @collection = apply_filters(@collection, params[:filters])

      respond_to do |f|
        if ModelsAuditor.config.respond_to_json_enabled
          f.json {
            render json: {
              ModelsAuditor.config.json_response_data_key => structure_requests_data(@collection),
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
      if filters[:since_at].present? && (time = (Time.parse(filters[:since_at]) rescue nil)).present?
        collection =
          collection
            .where(ModelsAuditor::AuditRecord.arel_table[:created_at].gteq(time))
            .references(ModelsAuditor::AuditRecord.table_name.to_sym)
      end
      if filters[:before_at].present? && (time = (Time.parse(filters[:before_at]) rescue nil)).present?
        collection =
          collection
            .where(ModelsAuditor::AuditRecord.arel_table[:created_at].lteq(time))
            .references(ModelsAuditor::AuditRecord.table_name.to_sym)
      end
      if filters[:action].present?
        collection = collection.where(ModelsAuditor::AuditRecord.arel_table[:action].eq(ModelsAuditor::AuditRecord.actions[filters[:action]])).references(ModelsAuditor::AuditRecord.table_name.to_sym)

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

        filtered_requests = collection.where(ModelsAuditor::AuditRecord.table_name.to_sym => cond).pluck(:id)
        collection        = collection.where(id: filtered_requests)
      end

      collection
    end

    def get_relations(record, records)
      rel_records = records.select { |r| !r.bridge.nil? && r.bridge.keys.include?(record.object_type) }
      rel_records.map do |i|
        target_class = i.bridge.except(record.object_type).keys.first
        next unless target_class
        i.attributes.slice('id', 'object_type', 'object_id').merge(target: {target_class => i.bridge[target_class].values.first})
      end.compact
    end

    # @param [ActiveRecord::Relation|ModelsAuditor::AuditRequest|Array] data
    def structure_requests_data(data)
      requests =
        case data
          when ActiveRecord::Relation
            data.to_a
          when ModelsAuditor::AuditRequest
            [data]
          when Array
            data
          else
            raise ArgumentError('Incorrect type of argument `requests`')
        end

      requests.map do |request|
        records = request.records
        {}.tap do |result|
          changed_models_collection =
            records
              .select { |record| record.bridge.nil? }
              .map do |record|
              {
                data:          record.attributes.slice('id', 'object_type', 'object_id'),
                relationships: get_relations(record, records)
              }
            end

          result[:request]   = request.as_json
          result[:changes_struct] = changed_models_collection.group_by { |i| i[:data]['object_type'] }
          result[:all_changes]    = records.map(&:as_json)
        end
      end
    end
  end
end
