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
        part = email.text_part || email.html_part || email
        @plain_text_body = Redmine::CodesetUtil.to_utf8(part.body.decoded, part.charset)
    
        email_images = {}
        email.part.each do |part|
            if part['Content-ID']
                cid = "cid:#{part['Content-ID'].element.message_ids[0]}"
                image = part.header['Content-Type'].parameters['name']
                email_images[cid] = image
            end
        end
        
        # replace html images with text bang notation
        email_doc = Nokogiri::HTML(@plain_text_body)
        email_doc.xpath('//img').each do |image|
            image_bang = "\n!#{email_images[image['src']]}!"
            image.replace(email_doc.create_text_node(image_bang))
        end
        @plain_text_body = email_doc.to_html
        
        # strip html tags and remove doctype directive
        @plain_text_body = strip_tags(@plain_text_body.strip)
        @plain_text_body.sub! %r{^<!DOCTYPE .*$}, ''
        @plain_text_body
      end
      
    end # module InstanceMethods
  end # module MailHandlerPatch
end # module RedmineEmailInlineImages

# Add module to MailHandler class
MailHandler.send(:include, RedmineEmailInlineImages::MailHandlerPatch)
