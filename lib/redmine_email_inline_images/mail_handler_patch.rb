module RedmineEmailInlineImages
  module MailHandlerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
      
      base.class_eval do
        alias_method_chain :plain_text_body, :email_inline_images
        alias_method_chain :add_attachments, :cid_name
        alias_method_chain :accept_attachment?, :checking_truncation
        alias_method_chain :issue_attributes_from_keywords, :parent_id
      end
    end
    
    module InstanceMethods
      private
      # Overrides the plain_text_body method to
      # include inline images from an email for
      # an issue created by an email request
      def plain_text_body_with_email_inline_images
        return @plain_text_body_with_inline_images unless @plain_text_body_with_inline_images.nil?
        part = email.html_part || email.text_part || email
        body_charset = Mail::RubyVer.respond_to?(:pick_encoding) ?
                        Mail::RubyVer.pick_encoding(part.charset).to_s : part.charset
        body = Redmine::CodesetUtil.to_utf8(part.body.decoded, body_charset)
    
        email_images = {}
        email.all_parts.each do |part|
            if part['Content-ID']
                email_images["cid:#{cid(part)}"] = short_cid_name(part)
            end
        end
        
        # replace html images with text bang notation
        email_doc = Nokogiri::HTML(body)
        email_doc.xpath('//img').each do |image|
            image_deleted = accept_attachment_name?(email_images[image['src']]) ? "" : "(image deleted)"
            case Setting.text_formatting
            when 'markdown'
                image_bang = "\n![#{image_deleted}](#{email_images[image['src']]})"
            when 'textile'
                image_bang = "\n!#{email_images[image['src']]}#{image_deleted}!"
            else
                image_bang = nil
            end
            image.replace(email_doc.create_text_node(image_bang)) if image_bang
        end
        body = email_doc.to_html
        
        # strip html tags and remove doctype directive
        body = self.class.html_body_to_text(body).gsub(%r{^[\t ]+}, '')

        # Simplify mail address
        regex = Regexp.new('(?m-x:(?<=[;\uFF1A:]|[;\uFF1A:]\*\*) ([^<\r\n]+) < ?(?:\[[\w@\.]+\]\(([\w@:\.]+)\)|([\w@:\.]+)) ?>(?=;| ?$))')
        body = body.gsub(regex, ' [\1](\2)') unless body.nil?

        @plain_text_body_with_inline_images = body
        @plain_text_body_with_inline_images
      end

      def cid(part)
        if part['Content-ID'].respond_to?(:element)
          content_id = part['Content-ID'].element.message_ids[0]
        else
          content_id = part['Content-ID'].value.gsub(%r{(^<|>$)}, '')
        end
        content_id
      end

      def short_cid_name(attachment)
        if attachment['Content-ID']
          content_id = cid(attachment)
          cid_name = content_id[-8,8] + '-' + attachment.header['Content-Type'].parameters['name']
        else
          # fail-safe to filename
          cid_name = attachment.filename.to_s
        end
        cid_name
      end

      # Returns false if the +attachment+'s name of the incoming email should be ignored
      def accept_attachment_name?(attachment_name)
        @excluded ||= Setting.mail_handler_excluded_filenames.to_s.split(',').map(&:strip).reject(&:blank?)
        @excluded.each do |pattern|
          regexp = %r{\A#{Regexp.escape(pattern).gsub("\\*", ".*")}\z}i
          if attachment_name =~ regexp
            logger.info "MailHandler: ignoring attachment #{attachment_name} matching #{pattern}"
            return false
          end
        end
        true
      end

      def add_attachments_with_cid_name(obj)
        if email.attachments && email.attachments.any?
          email.attachments.each do |attachment|
            next unless accept_attachment?(attachment)
            obj.attachments << Attachment.create(:container => obj,
                              :file => attachment.body.decoded,
                              :filename => short_cid_name(attachment),
                              :author => user,
                              :content_type => attachment.mime_type)
          end
        end
      end
    
      # Returns false if the +attachment+ is a truncated inline image, or the +attachment+ of the incoming email should be ignored by name.
      def accept_attachment_with_checking_truncation?(attachment)
        attachment_name = short_cid_name(attachment)
        @truncated_inline_images ||= find_inline_images_from_body(truncated_plain_text_body)
        @truncated_inline_images.each do |filename|
          if attachment_name == filename
            logger.info "MailHandler: ignoring attachment #{attachment_name} matching truncated inline image #{filename}"
            return false
          end
        end unless @truncated_inline_images.nil?
        accept_attachment_without_checking_truncation?(attachment)
      end

      def truncated_plain_text_body
        return @truncated_plain_text_body unless @truncated_plain_text_body.nil?

        ## Code refers cleanup_body in mail_handler.rb, with regex supported.
        delimiters = Setting.mail_handler_body_delimiters.to_s.split(/[\r\n]+/).reject(&:blank?)
    
        begin
          delimiters = delimiters.map {|s| Regexp.new(s)}
        rescue RegexpError => e
          logger.error "MailHandler: invalid regexp delimiter found in mail_handler_body_delimiters setting (#{e.message})" if logger
        end

        unless delimiters.empty?
          regex = Regexp.new("(#{ Regexp.union(delimiters) })", Regexp::MULTILINE)
          @truncated_plain_text_body = plain_text_body.scan(regex).join("\r\n") || ""
        end

        @truncated_plain_text_body
      end

      # Find filenames for truncated inline images.
      def find_inline_images_from_body(body)
        body.scan(/(?-m:(?<=\!\[\]\()[^\r\n\)]*(?=\))|(?<=\!)[^\r\n\)]*(?=\!))/).uniq
      end
    
      # Overrides the issue_attributes_from_keywords method to
      # include parent_id into issue_attribute
      def issue_attributes_from_keywords_with_parent_id(issue)
        attrs = issue_attributes_from_keywords_without_parent_id(issue)
        k = get_keyword(:parent_issue)
        attrs['parent_issue_id'] = k unless k.blank?

        attrs
      end
  
    end # module InstanceMethods
  end # module MailHandlerPatch
end # module RedmineEmailInlineImages
