module ModelsAuditor
  module Audit
    # Сбор данных через метод #as_json
    #   @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON, only: [:title, :subtitle, :published_at]
    AUDIT_MODE_JSON         = 1
    # Сбор данных через сериалайзер
    #   @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_SERIALIZER, serializer: AuditPostSerializer
    AUDIT_MODE_SERIALIZER   = 2
    # Сбор данных через назначенный метод
    #  @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_SERIALIZER, method: :logged_data
    AUDIT_MODE_METHOD       = 3
    # Сбор данных через #previous_changes
    #  @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_CHANGES_ONLY
    AUDIT_MODE_CHANGES_ONLY = 4

    AUDIT_SNAPSHOT_MODES = [AUDIT_MODE_JSON, AUDIT_MODE_SERIALIZER, AUDIT_MODE_METHOD]
    AUDIT_CHANGES_MODES  = [AUDIT_MODE_CHANGES_ONLY]

    def self.included(base)
      base.send :extend, ClassMethods
    end

    module InstanceMethods
      def do_audit_init_snapshot
        return unless ModelsAuditor.config.audit_enabled
        mode = self.class.instance_variable_get(:@audit_mode)
        return unless self.class.instance_variable_get(:@audit_enabled) && AUDIT_SNAPSHOT_MODES.include?(mode)
        ma_store_initial_state(ModelsAuditor.store)
      end

      def do_audit_process
        return unless ModelsAuditor.config.audit_enabled
        return unless self.class.instance_variable_get(:@audit_enabled)
        mode    = self.class.instance_variable_get(:@audit_mode)
        options = self.class.instance_variable_get(:@audit_settings) || {}
        store   = ModelsAuditor.store

        initial_data = ma_get_initial_state(store)
        current_data = ma_auditor_get_data

        action =
          case
            when transaction_include_any_action?([:create])
              ModelsAuditor::AuditRecord::ACTION_CREATE
            when transaction_include_any_action?([:update])
              ModelsAuditor::AuditRecord::ACTION_UPDATE
            when transaction_include_any_action?([:destroy])
              ModelsAuditor::AuditRecord::ACTION_DESTROY
          end

        bridge =
          if options[:bridge]
            options[:bridge].each_with_object({}) { |(key, model_name), o| o[key] = {model_name => __send__(key)} }
          end

        Thread.new do
          begin
            log_anyway = !ModelsAuditor.config.audit_request_changes_only
            if (request = store[:audit_request]) || log_anyway
              body =
                case
                  when AUDIT_SNAPSHOT_MODES.include?(mode)
                    ma_eliminate_not_changed_keys(initial_data, current_data)
                  when AUDIT_CHANGES_MODES.include?(mode)
                    current_data
                  else
                    raise ArgumentError.new('Incorrect value of argument audit_type')
                end

              if request.try(:new_record?) && !request.save
                ModelsAuditor.log_error("Couldn't save request record")
                ModelsAuditor.log_error(request.errors.full_messages)
                return
              end
              record =
                ModelsAuditor::AuditRecord.new(
                  request:   request,
                  auditable: self,
                  content:   body,
                  action:    action,
                  bridge:    bridge
                )
              unless record.save
                ModelsAuditor.log_error("Couldn't logged changes of #{self.class.name} id: #{self.try(:id)}")
                ModelsAuditor.log_error(record.errors.full_messages)
              end
            end
          rescue StandardError => e
            ModelsAuditor.log_error("Couldn't logged changes of #{self.class.name} id: #{self.try(:id)}")
            ModelsAuditor.log_error(e.message)
            ModelsAuditor.log_error(e.backtrace.take(100).join("\n"))
          end
        # TODO To remove the #join call from the thread block after debugging
        end.join
      end

      private

      # Сравнивает два хэша, оставляя только отличающиеся по значению ключи
      # @return [Hash] filtered result with different attributes only
      def ma_eliminate_not_changed_keys(old_hash, new_hash)
        case
          # Равны или оба nil
          when old_hash == new_hash
            {}
          # Один из них nil
          when (old_hash && new_hash).nil?
            (old_hash || new_hash).keys.each_with_object({}) do |key, o|
              if (was = old_hash.try(:[], key)) != (now = new_hash.try(:[], key))
                o[key] = [was, now]
              end
            end
          else # Оба не nil
            (old_hash.keys | new_hash.keys).each_with_object({}) do |key, o|
              if (was = old_hash[key]) != (now = new_hash[key])
                o[key] = [was, now]
              end
            end
        end
      end

      # Запоминает сериализованные данные для аудита
      #   Вызывать данный метод следует в коллбэке after_initialize
      #   Или в любом другом месте до изменения значений аттрибутов
      def ma_store_initial_state(store)
        store[:initial_states]    ||= {}
        states_of_mclass          = (store[:initial_states][self.class.name] ||= {})
        states_of_mclass[self.id] ||= ma_auditor_get_data
      end

      # Получает сериализованные данные для аудита подготовленные при инициализации сущности
      # @return [Hash|nil] Начальные данные
      def ma_get_initial_state(store)
        store[:initial_states].try(:[], self.class.name).try(:[], self.id)
      end

      # Получает сериализованные данные для аудита
      def ma_auditor_get_data
        options      = self.class.instance_variable_get(:@audit_settings) || {}
        audit_params = options[:params]
        mode         = self.class.instance_variable_get(:@audit_mode)
        case mode
          when AUDIT_MODE_JSON
            self.as_json(audit_params)
          when AUDIT_MODE_SERIALIZER
            if (serializer = options[:serializer]).blank?
              raise ArgumentError.new('Required option :serializer for AUDIT_MODE_SERIALIZER was not passed')
            end
            serializer.new(self, audit_params || {}).as_json
          when AUDIT_MODE_METHOD
            if (method = options[:serializer]).blank?
              raise ArgumentError.new('Required option :method for AUDIT_MODE_METHOD was not passed')
            end
            unless self.respond_to?(method)
              raise ArgumentError.new("Passed method '#{method}' is undefined")
            end
            self.__send__(method)
          when AUDIT_MODE_CHANGES_ONLY
            self.previous_changes
          else
            raise ArgumentError.new('Incorrect value of argument audit_type')
        end
      end
    end


    module ClassMethods
      # Активирует аудит изменений данных модели
      # @param [Integer] audit_mode Способ логирования
      #   возможные значения: AUDIT_MODE_JSON | AUDIT_MODE_SERIALIZER | AUDIT_MODE_METHOD | AUDIT_MODE_CHANGES_ONLY
      #   AUDIT_MODE_JSON         - Сериализация путем вызова метода as_json
      #   AUDIT_MODE_SERIALIZER   - Сериализация через использование сериалайзера, указанного в опции :serializer
      #   AUDIT_MODE_METHOD       - Сериализация данных формируемых в методе, указанном в опции :method
      #   AUDIT_MODE_CHANGES_ONLY - Сериализация данных модели, которые были изменены
      # @param [Hash] options Настройки логирования
      # @option options [params] Параметры сериализации данных.
      #   Для AUDIT_MODE_JSON         значение передается в метод #as_json
      #     @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_JSON, only: [:title, :subtitle, :published_at]
      #   Для AUDIT_MODE_SERIALIZER   значение передается в сериалайзер в качестве опций
      #     @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_SERIALIZER, serializer: AuditPostSerializer
      #   Для AUDIT_MODE_METHOD       значение игнорируется
      #     @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_SERIALIZER, method: :logged_data
      #   Для AUDIT_MODE_CHANGES_ONLY значение игнорируется
      #     @example enable_audit ModelsAuditor::Audit::AUDIT_MODE_CHANGES_ONLY
      def enable_audit(audit_mode, options = {})
        @audit_enabled  = true
        @audit_mode     = audit_mode
        @audit_settings = options
        # Lazily include the instance methods so we don't clutter up
        # any more ActiveRecord models than we have to.
        send :include, InstanceMethods
        after_initialize :do_audit_init_snapshot
        after_commit :do_audit_process
      end

      # Дезактивирует аудит изменений данных модели
      def disable_audit
        @audit_enabled = false
      end
    end
  end
end