class RDFConfig
  class Schema
    class Chart
      class Validator
        attr_reader :errors, :warnings

        def initialize(model, config, schema_name)
          @model = model
          @config = config
          @schema_name = schema_name

          @errors = []
          @warnings = []
        end

        def validate
          if @config.schema.key?(@schema_name)
            return unless @config.schema[@schema_name].key?('variables')

            if @config.schema[@schema_name]['variables'].is_a?(Array)
              validate_variable_names(@config.schema[@schema_name]['variables'])
            else
              add_error('Variables is not an array. Please specify variables as an array.')
            end
          else
            add_error("Schema name '#{@schema_name}' is specified but not found in schema.yaml file.")
          end
        end

        def add_error(error_message)
          @errors << error_message
        end

        def error_message
          %Q(ERROR: Invalid configuration. Please check the setting in schema.yaml file.\n#{errors.map { |msg| "  #{msg}" }.join("\n")})
        end

        def add_warning(warn_message)
          @warnings << warn_message
        end

        def error?
          !@errors.empty?
        end

        def warning?
          !@warnings.empty?
        end

        private

        def validate_variable_names(variable_names)
          subject_names = @model.subject_names
          object_names = @model.object_names
          variable_names.each do |variable_name|
            if !subject_names.include?(variable_name) && !object_names.include?(variable_name)
              add_error("Variable name '#{variable_name}' is not specified in model.yaml file.")
            end
          end
        end
      end
    end
  end
end
