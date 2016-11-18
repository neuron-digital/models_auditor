module ModelsAuditor
  class DefaultFormatter
    def initialize(collection)
      @collection = collection
    end

    # @param [ActiveRecord::Relation|ModelsAuditor::AuditRequest|Array] data
    def as_json
      requests =
        case @collection
          when ActiveRecord::Relation
            @collection.to_a
          when ModelsAuditor::AuditRequest
            [@collection]
          when Array
            @collection
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

    private

    # @return [Array]
    def except_target_class(bridge, target_class, target_id)
      target_id = target_id.to_i
      bridge.select do |_, v|
        klass, id = v.to_a[0]
        !(klass.to_s == target_class.to_s && id.to_i == target_id.to_i)
      end
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
  end
end