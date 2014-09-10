module Raml
  module Parameter
    class AbstractParameter < PropertiesNode
      inherit_class_attributes

      include Documentable
      include Merge
      include Parent

      VALID_TYPES = %w(string number integer date boolean file)

      scalar_property :type       , :enum     , :pattern  , :min_length , 
                      :max_length , :minimum  , :maximum  , :example    , 
                      :repeat     , :required , :default

      attr_reader_default :type    , 'string'
      attr_reader_default :repeat  , false
      attr_reader_default :required, false

      children_by :types, :type, AbstractParameter

      def initialize(name, parameter_data, parent)
        if parameter_data.is_a? Array
          @name       = name
          @children ||= []
          parameter_data.each do |parameter|
            @children << self.class.new(name, parameter, self)
          end
        elsif parameter_data.is_a? Hash
          super
        end
      end

      def document
        lines = []

        if @children.any?
          lines = @children.map(&:document)
        else
          lines << "*#{@display_name || @name}:*"
          lines << "&nbsp;&nbsp;#{@description}" if @description
          lines << "&nbsp;&nbsp;type: #{@type}" if @type
          lines << "&nbsp;&nbsp;required: #{@required}" if @required
          lines << "&nbsp;&nbsp;enum: #{@enum}" if @enum
          lines << "&nbsp;&nbsp;pattern: #{@pattern}" if @pattern
          lines << "&nbsp;&nbsp;min_length: #{@min_length}" if @min_length
          lines << "&nbsp;&nbsp;max_length: #{@max_length}" if @max_length
          lines << "&nbsp;&nbsp;minimum: #{@minimum}" if @minimum
          lines << "&nbsp;&nbsp;maximum: #{@maximum}" if @maximum
          lines << "&nbsp;&nbsp;example: `#{@example}`" if @example
          lines << "&nbsp;&nbsp;repeat: #{@repeat}" if @repeat
          lines << "\n"
        end

        lines.join "  \n"
      end

      def has_multiple_types?
        not children.empty?
      end
      
      def merge(base)
        raise MergeError, "#{self.class} names don't match." if name != base.name

        case [ has_multiple_types?, base.has_multiple_types? ]
        when [ true , true  ]
          match, no_match = base.types.values.partition { |param| types.include? param.type }

          # Merge parameters with the same type.
          match = Hash[ match.map { |param| [ param.type, param ] } ]
          types.each { |type, param| param.merge match[type] if match[type] }

          # Add parameters with no matching type.
          @children.concat no_match

        when [ true , false ]
          if types[base.type]
            types[base.type].merge base
          else
            @children << base
          end

        when [ false, true  ]
          if base.types[self.type]
            self.merge base.types[self.type]
            @children << self.clone
            @children.concat base.types.values.reject { |type| self.type == type.type }
            reset

          else
            @children << self.clone
            @children.concat base.types.values
            reset
          end

        when [ false, false ]
          super
        end

        self
      end

      private
      
      def validate_type
        raise InvalidParameterType unless VALID_TYPES.include? type
      end

      def validate_enum
        if enum
          if type == 'string'
            raise InvalidParameterAttribute, 'enum attribute must be an array of strings.' unless
              enum.is_a?(Array) && enum.all? { |val| val.is_a? String }
          else
            raise InapplicableParameterAttribute, 'enum attribute is only applicable to string parameters.'
          end
        end
      end
      
      def validate_pattern
        if pattern
          if type == 'string'
            raise InvalidParameterAttribute, 'pattern attribute must be a string' unless pattern.is_a? String
            pattern.gsub!(/\\*\^/u) { |m| m.size.odd? ? "#{m.chop}\\A" : m }
            pattern.gsub!(/\\*\$/u) { |m| m.size.odd? ? "#{m.chop}\\z" : m }
            begin
              @pattern = Regexp.new pattern
            rescue RegexpError
              raise InvalidParameterAttribute, 'pattern attribute must be a valid regexp'
            end
          else
            raise InapplicableParameterAttribute, 'pattern attribute is only applicable to string parameters.'
          end          
        end
      end
      
      def validate_min_length
        if min_length
          if type != 'string'
            raise InapplicableParameterAttribute, 'minLength attributes are applicable only to string parameters.'
          else
            raise InvalidParameterAttribute, 'minLength attributes must be an integer' unless min_length.is_a? Integer
          end
        end
      end
      
      def validate_max_length
        if max_length
          if type != 'string'
            raise InapplicableParameterAttribute, 'maxLength attributes are applicable only to string parameters.'
          else
            raise InvalidParameterAttribute, 'maxLength attributes must be an integer' unless max_length.is_a? Integer
          end
        end
      end
      
      def validate_minimum
        if minimum
          if %w(integer number).include? type
            raise InvalidParameterAttribute, 'minimum attribute must be numeric' unless minimum.is_a? Numeric
          else
            raise InapplicableParameterAttribute, 
              'minimum attribute applicable only to number or integer parameters.'
          end
        end
      end
      
      def validate_maximum
        if maximum
          if %w(integer number).include? type
            raise InvalidParameterAttribute, 'maximum attribute must be numeric' unless maximum.is_a? Numeric
          else
            raise InapplicableParameterAttribute, 
              'maximum attribute applicable only to number or integer parameters.'
          end
        end
      end
      
      def validate_example
        validate_value :example
      end
      
      def validate_repeat
        unless [true, false].include?(repeat)
          raise InvalidParameterAttribute, 'repeat attribute must be true or false.'
        end
      end
      
      def validate_required
        unless [true, false].include?(required)
          raise InvalidParameterAttribute, 'required attribute must be true or false.'
        end
      end
      
      def validate_default
        validate_value :default
      end
      
      def validate_value(which)
        val = send which
        if val
          err_msg = "#{which} attribute for a %s parameter must be a %s"
          case type
          when 'string'
            raise InvalidParameterAttribute, 
              ( err_msg % [ 'string' , 'string'  ] ) unless val.is_a? String
          when 'number'
            raise InvalidParameterAttribute, 
              ( err_msg % [ 'number' , 'number'  ] ) unless val.is_a? Numeric
          when 'integer'
            raise InvalidParameterAttribute, 
              ( err_msg % [ 'integer', 'integer' ] ) unless val.is_a? Integer
          when 'date'
            raise InvalidParameterAttribute, 
              ( err_msg % [ 'date'   , 'string'  ] ) unless val.is_a? String
          when 'boolean'
            raise InvalidParameterAttribute, 
              ( err_msg % [ 'boolean', 'boolean' ] ) unless [TrueClass, FalseClass].include? val.class
          end
        end
      end

      def reset
        scalar_properties.each { |prop| instance_variable_set "@#{prop}", nil }
      end
    end
  end
end
