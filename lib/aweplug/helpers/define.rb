module Aweplug
  module Helpers
    module Define

      def define name
        content = yield
        self.send("#{name}=", content)
        nil
      end

    end
  end
end

