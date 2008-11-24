class CGI
  class Session
  
    def session_id
      @data ||= @dbman.restore
      if @data[:session_id]
        @data[:session_id]
      else
        @session_id
      end    
    end
      
  end
end