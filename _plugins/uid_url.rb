module Jekyll
  class UIDUrl < Liquid::Tag
    def initialize(tag_name, input, tokens)
      @input = input
      super
    end

    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]
      uid = @input.strip

      return unless site && page && uid

      current_language = page["lang"]

      doc_by_uid = doc_by_uid(site, uid, current_language)

      if doc_by_uid
        doc_by_uid.url
      else
        ""
      end
    end

    private

    def doc_by_uid(site, uid, current_language)
      docs = site.posts.docs + site.pages

      docs_by_uid = docs.filter { |doc| doc["uid"] == uid}
      doc_by_language(site, docs_by_uid, current_language)
    end

    def doc_by_language(site, docs, current_language)
      doc_by_language = docs.find {|doc| doc["lang"] == current_language}

      if doc_by_language
        doc_by_language
      else
        languages = site.config["languages"]
        languages.reduce(nil) {|doc, language|
          docs.find {|doc| doc["lang"] == language["code"]} || doc
        }
      end
    end
  end
end

Liquid::Template.register_tag("uid_url", Jekyll::UIDUrl)
