module Jekyll
  class PageBreak < Liquid::Tag
    def initialize(tag_name, input, tokens)
      @input = input
      super
    end

    def render(context)
      '<div style="page-break-after: always"></div>'
    end
  end
end

Liquid::Template.register_tag("page_break", Jekyll::PageBreak)
