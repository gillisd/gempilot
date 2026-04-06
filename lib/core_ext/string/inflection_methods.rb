require "strscan"

module String::InflectionMethods
  def dasherize(name) = name.to_s.tr("_", "-")

  def underscore(name)
    scanner    = StringScanner.new(name.to_s)
    new_string = String.new
    until scanner.eos?
      if (separator = scanner.scan(/[_-]+/))
        new_string << ("_" * separator.length)
      else
        if (capitalized = scanner.scan(/[A-Z][a-z\d]+/))
          new_string << capitalized
        elsif (uppercase = scanner.scan(/[A-Z][A-Z\d]*(?=[A-Z_-]|$)/))
          new_string << uppercase
        elsif (lowercase = scanner.scan(/[a-z][a-z\d]*/))
          new_string << lowercase
        else
          raise(ArgumentError, "cannot convert string to underscored: #{scanner.string.inspect}")
        end
        if (separator = scanner.scan(/[_-]+/))
          new_string << ("_" * separator.length)
        elsif !scanner.eos?
          new_string << "_"
        end
      end
    end
    new_string.downcase!
    new_string
  end

  def camelize(name)
    scanner = StringScanner.new(name.to_s)
    new_string = String.new
    until scanner.eos?
      if (word = scanner.scan(/[A-Za-z\d]+/))
        word.capitalize!
        new_string << word
      elsif (numbers = scanner.scan(/[_-]\d+/))
        new_string << "_#{numbers[1..]}"
      elsif scanner.scan(/[_-]+/)
      elsif scanner.scan(%r{/})
        new_string << "::"
      else
        raise(ArgumentError, "cannot convert string to CamelCase: #{scanner.string.inspect}")
      end
    end
    new_string
  end
end
