module RedmineEmailInlineImages
  module MailHandlerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
      
      base.class_eval do
        alias_method_chain :plain_text_body, :email_inline_images
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
      
    end # module InstanceMethods
  end # module MailHandlerPatch
end # module RedmineEmailInlineImages
