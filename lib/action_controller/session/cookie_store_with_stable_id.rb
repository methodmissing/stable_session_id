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
          log("initialize with stable id")
          options.reverse_merge!( 'stable_session_id' => false )
          @stable_session_id = options['stable_session_id']
          initialize_without_stable_id( session, options )
        end
        
        def marshal_with_stable_id( session )
          log("marshal with stable id")
          session = stable_session_id!( session )
          log_session_id
          marshal_without_stable_id( session )
        end
        
        def unmarshal(cookie)
          log("unmarshal cookie")
          if cookie
            begin
              log("have a cookie")
              log_session_id
              cookie_data = verifier.verify(cookie)
              stable_session_id!( cookie_data )
            rescue ActiveSupport::MessageVerifier::InvalidSignature
              log("invalid cookie signature")
              log_session_id
              delete
              raise TamperedWithCookie
            end
          end
        end        
        
        def stable_session_id!( data  )
          log( data.inspect )
          return data unless @stable_session_id
          ( data ||= {} ).merge( inject_stable_session_id!( data ) )
          @session.instance_variable_set(:@session_id, data[:session_id]) if @stable_session_id
          data
        end

        def inject_stable_session_id!( data )
          log( data.inspect )
          if data.respond_to?(:key?) && !data.key?( :session_id )
            log("inject stable session id")
            { :session_id => CGI::Session.generate_unique_id }
          else
            log("do not inject stable session id")
           {}
          end  
        end        
        
        def log_session_id
          log @session.instance_variable_get(:@session_id)
        end
        
        def log( message )
          ::ActionController::Base.logger.info( "** #{message}" ) if ::ActionController::Base.logger
        end
        
      end
            
    end
  end
end

ActionController::Session::CookieStoreWithStableSessionId.install!