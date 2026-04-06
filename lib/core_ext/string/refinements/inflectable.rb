require_relative "../inflection_methods"

module String::Inflectable
  refine String.singleton_class do
    import_methods String::InflectionMethods
  end

  refine String do
    def dasherize
      self.class.dasherize(self)
    end

    def underscore
      self.class.underscore(self)
    end

    def camelize
      self.class.camelize(self)
    end
  end
end
