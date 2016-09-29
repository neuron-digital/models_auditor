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
          .order(created_at: :desc)
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
      rel_records = records.select do |r|
        !r.bridge.nil? && r.bridge.any? do |_, v|
          v_type, v_id = v.to_a[0]
          v_type.to_s == record.object_type && v_id.to_i == record.object_id.to_i
        end
      end
      rel_records.map do |i|
        target_info = except_target_class(i.bridge, record.object_type, record.object_id)
        next if target_info.empty?
        t_key, klass_with_id = target_info.to_a[0]
        target_klass, target_id = klass_with_id.to_a[0]
        i.attributes.slice('id', 'object_type', 'object_id').merge(target: {
          class: target_klass,
          foreign_key: t_key,
          foreign_id: target_id,
        })
      end.compact
    end

    # @return [Array]
    def except_target_class(bridge, target_class, target_id)
      target_id = target_id.to_i
      bridge.select do |_, v|
        klass, id = v.to_a[0]
        !(klass.to_s == target_class.to_s && id.to_i == target_id.to_i)
      end
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
