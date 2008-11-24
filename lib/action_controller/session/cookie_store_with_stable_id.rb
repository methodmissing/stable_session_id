module ActionController
  module Session
    module CookieStoreWithStableSessionId
      
      def self.install!
        ::CGI::Session::CookieStore.send :include, self
      end
      
      def self.included( base )
        base.send :include, InstanceMethods      
        base.alias_method_chain :initialize, :stable_id
        base.alias_method_chain :marshal, :stable_id
      end
      
      module InstanceMethods
        
        def initialize_with_stable_id( session, options = {} )
          options.reverse_merge!( 'stable_session_id' => false )
          @stable_session_id = options['stable_session_id']
          initialize_without_stable_id( session, options )
        end
        
        def marshal_with_stable_id( session )
          session = stable_session_id!( session )
          marshal_without_stable_id( session )
        end
        
        def unmarshal(cookie)
          if cookie
            cookie_data = verifier.verify(cookie)
            stable_session_id!( cookie_data )
          end
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            delete
            raise TamperedWithCookie
        end        
        
        def stable_session_id!( data  )
          return data unless @stable_session_id
          ( data ||= {} ).merge!( inject_stable_session_id!( data ) )
          @session.instance_variable_set(:@session_id, data[:session_id])
          data
        end

        def inject_stable_session_id!( data )
          if data.respond_to?(:key?) && !data.key?( :session_id )
            { :session_id => CGI::Session.generate_unique_id }
          else
           {}
          end  
        end        
        
      end
            
    end
  end
end

ActionController::Session::CookieStoreWithStableSessionId.install!