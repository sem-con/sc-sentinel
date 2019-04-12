module DataAccessHelper
    def getData(params)
    	require 'securerandom'

    	# check if request ID is present
    	if params["rid"].nil?
            return [{"error": "not found"}.to_json]
    	else
    		rid = params["rid"].to_s
    		@ap = AsyncProcess.find_by_rid(rid)
    		if @ap.nil?
    			return []
    		else
	    		case @ap.status
	    		when 1
	    			# puts "job in progress"
	    		when 2
	    			# puts "job finished"
	    			retVal = [{ "type": "files", 
                                "directory": rid.to_s, 
                                "hash": @ap.file_hash.to_s }.to_json]
	    			return retVal
	    		when -1
	    			# puts "stopped with error"
	    			return [{"error": "processing"}.to_json]
	    		end
    		end
    	end
		[{ "rid": rid, "status": @ap.status }.to_json]
    end
end