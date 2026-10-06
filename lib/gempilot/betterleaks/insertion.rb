module Gempilot
  class Betterleaks
    ## A snippet the betterleaks integration ensures is present in one of the
    ## gem's own files. Idempotent: skipped when the snippet is already there.
    ##
    ## When +before+ (a line-matching Regexp) is given, the snippet is woven in
    ## just above the first matching line -- so wiring lands next to a gem's
    ## +task default+ rather than at end-of-file -- otherwise it is appended.
    class Insertion
      attr_reader :path, :snippet, :before

      def initialize(path:, snippet:, before: nil)
        @path = path
        @snippet = snippet
        @before = before
      end

      def install(generator)
        body = File.exist?(path) ? File.read(path) : ""
        return generator.skip(path) if body.include?(snippet.strip)

        generator.update(path, woven(body))
      end

      private

      def woven(body)
        return normalized if body.empty?

        anchor = before && body.index(before)
        return "#{body.chomp}\n\n#{normalized}" unless anchor

        "#{body[0...anchor]}#{normalized}\n#{body[anchor..]}"
      end

      def normalized
        snippet.end_with?("\n") ? snippet : "#{snippet}\n"
      end
    end
  end
end
