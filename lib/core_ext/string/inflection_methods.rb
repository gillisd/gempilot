require "strscan"

class String
  ## Pure string inflection utilities (dasherize, underscore, camelize).
  ## Used via String::Inflectable refinement.
  module InflectionMethods
    UPPERCASE_ACRONYM_PATTERN = /[A-Z][A-Z\d]*(?=[A-Z_-]|$)/
    private_constant :UPPERCASE_ACRONYM_PATTERN

    def dasherize(name) = name.to_s.tr("_", "-")

    def underscore(name)
      scanner    = StringScanner.new(name.to_s)
      new_string = +""
      append_underscore_token(scanner, new_string) until scanner.eos?
      new_string.downcase!
      new_string
    end

    def camelize(name)
      scanner    = StringScanner.new(name.to_s)
      new_string = +""
      append_camelize_token(scanner, new_string) until scanner.eos?
      new_string
    end

    private

    def scan_word_token(scanner)
      scanner.scan(/[A-Z][a-z\d]+/) ||
        scanner.scan(UPPERCASE_ACRONYM_PATTERN) ||
        scanner.scan(/[a-z][a-z\d]*/) ||
        raise(ArgumentError, "cannot convert string to underscored: #{scanner.string.inspect}")
    end

    def scan_underscore_separator(scanner)
      if (sep = scanner.scan(/[_-]+/))
        "_" * sep.length
      elsif scanner.eos?
        ""
      else
        "_"
      end
    end

    def append_underscore_token(scanner, buffer)
      if (sep = scanner.scan(/[_-]+/))
        buffer << ("_" * sep.length)
      else
        buffer << scan_word_token(scanner)
        buffer << scan_underscore_separator(scanner)
      end
    end

    def append_camelize_token(scanner, buffer)
      return buffer << scanner.scan(/[A-Za-z\d]+/).capitalize if scanner.check(/[A-Za-z\d]/)
      return buffer << "_#{scanner.scan(/[_-]\d+/)[1..]}" if scanner.check(/[_-]\d/)

      if scanner.scan(/[_-]+/)
        nil
      elsif scanner.scan(%r{/})
        buffer << "::"
      else
        raise(ArgumentError, "cannot convert string to CamelCase: #{scanner.string.inspect}")
      end
    end
  end
end
