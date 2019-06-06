module Jekyll
  class LanguageSelector < Liquid::Tag
    def initialize(tag_name, input, tokens)
      @wrapper_class = 'language-selector'.freeze
      @link_class = 'language-selector-link'.freeze
      @disabled_link_class = 'language-selector-link-disabled'.freeze
      @separator_class = 'language-selector-separator'.freeze
      @separator = "<span class=\"#{@separator_class}\">|</span>".freeze
      @uid = input.strip if input.strip.length > 0
      super
    end

    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]
      uid = @uid || page && page["uid"]

      return unless site && page && uid

      current_language = page["lang"]

      links = alternative_language_links(site, uid, current_language)

      if links.length > 1
        <<-LANG_SELECTOR
        <div class="language-selector">
          #{links.join(@separator)}
        </div>
        LANG_SELECTOR
      else
        nil
      end
    end

    private

    def alternative_language_links(site, uid, current_language)
      languages = site.config["languages"]
      docs = site.posts.docs + site.pages

      docs_by_uid = docs.filter {|doc| doc["uid"] == uid}

      languages.reduce([]) {|links, language|
        doc_by_lang = docs_by_uid.find {|doc| doc["lang"] == language["code"]}

        if doc_by_lang
          if doc_by_lang["lang"] == current_language
            links.push(disabled_link(language["name"]))
          else
            links.push(link(doc_by_lang.url, language["name"]))
          end
        else
          links
        end
      }
    end

    def link(url, title)
      "<a href=\"#{url}\" class=\"#{@link_class}\">#{title}</a>"
    end

    def disabled_link(title)
      "<span class=\"#{@link_class}\">#{title}</span>"
    end
  end
end

Liquid::Template.register_tag("language_selector", Jekyll::LanguageSelector)
