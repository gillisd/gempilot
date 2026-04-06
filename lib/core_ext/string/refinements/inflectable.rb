require_relative "../inflection_methods"

class String
  ## Refinement that adds inflection methods (underscore, camelize, dasherize)
  ## to String and String singleton class via String::InflectionMethods.
  module Inflectable
    refine String.singleton_class do
      import_methods String::InflectionMethods
    end

    refine String do
      def dasherize = self.class.dasherize(self)
      def underscore = self.class.underscore(self)
      def camelize = self.class.camelize(self)
    end
  end
end
