module RedmineEmailInlineImages
  module MailHandlerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
      
      base.class_eval do
        alias_method_chain :plain_text_body, :email_inline_images
        alias_method_chain :accept_attachment?, :checking_truncation
      end
    end
    
    module InstanceMethods
      private
      # Overrides the plain_text_body method to
      # include inline images from an email for
      # an issue created by an email request
      def plain_text_body_with_email_inline_images
        return @plain_text_body unless @plain_text_body.nil?
        part = email.html_part || email.text_part || email
        @plain_text_body = Redmine::CodesetUtil.to_utf8(part.body.decoded, part.charset)
    
        email_images = {}
        email.all_parts.each do |part|
            if part['Content-ID']
                if part['Content-ID'].respond_to?(:element)
                    content_id = part['Content-ID'].element.message_ids[0]
                else
                    content_id = part['Content-ID'].value.gsub(%r{(^<|>$)}, '')
                end
                image = part.header['Content-Type'].parameters['name']
                email_images["cid:#{content_id}"] = image
            end
        end
        
        # replace html images with text bang notation
        email_doc = Nokogiri::HTML(@plain_text_body)
        email_doc.xpath('//img').each do |image|
            case Setting.text_formatting
            when 'markdown'
                image_bang = "\n![](#{email_images[image['src']]})"
            when 'textile'
                image_bang = "\n!#{email_images[image['src']]}!"
            else
                image_bang = nil
            end
            image.replace(email_doc.create_text_node(image_bang)) if image_bang
        end
        @plain_text_body = email_doc.to_html
        
        # strip html tags and remove doctype directive
        @plain_text_body = self.class.html_body_to_text(@plain_text_body)
        @plain_text_body.gsub! %r{^[\t ]+}, ''
        @plain_text_body
      end
      
      # Returns false if the +attachment+ is a truncated inline image, or the +attachment+ of the incoming email should be ignored by name.
      def accept_attachment_with_checking_truncation?(attachment)
        @truncated_inline_images ||= find_inline_images_from_body(truncated_plain_text_body)
        @truncated_inline_images.each do |filename|
          if attachment.filename.to_s == filename
            logger.info "MailHandler: ignoring attachment #{attachment.filename} matching truncated inline image #{filename}"
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
          regex = Regexp.new("^[> ]*(#{ Regexp.union(delimiters) })[[:blank:]]*[\r\n].*", Regexp::MULTILINE)
          @truncated_plain_text_body = @plain_text_body[regex, 0] || ""
        end

        @truncated_plain_text_body
      end

      # Find filenames for truncated inline images.
      def find_inline_images_from_body(body)
        body.scan(/(?<=^\!\[\]\().*(?=\))|(?<=^\!).*(?=\!)/).uniq
      end

    end # module InstanceMethods
  end # module MailHandlerPatch
end # module RedmineEmailInlineImages