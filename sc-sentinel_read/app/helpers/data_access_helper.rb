module DataAccessHelper
    def getData(params)
    	require 'securerandom'

    	# check if request ID is present
    	if params["rid"].nil?
    		# check if request was sent before
    		request_string = request.query_string
    		lat = CGI::parse(request_string)["lat"].first.to_f rescue nil
    		long = CGI::parse(request_string)["long"].first.to_f rescue nil
			start_date = Date.parse(CGI::parse(request_string)["start"].first) rescue Time.now.to_date
			end_date = Date.parse(CGI::parse(request_string)["end"].first) rescue Time.now.to_date-14.days

			normalized_request = "lat=" + lat.to_s
			normalized_request += "&long=" + long.to_s
			normalized_request += "&start=" + start_date.to_s
			normalized_request += "&end=" + end_date.to_s

    		@ap = AsyncProcess.find_by_request(normalized_request)
    		if @ap.nil?
    			# write new entry to table
    			if params["fid"].nil?
    				rid = SecureRandom.uuid
    			else
    				rid = params["fid"].to_s
    			end
    			@ap = AsyncProcess.new(
    				request: normalized_request,
    				rid: rid,
    				status: 0) # status 0 - job initialized
    			@ap.save

    			# setup job
    			ApplicationJob.perform_later rid

    			# return Request ID
    			puts "returning: " + rid.to_s
				return [{ "rid": rid, "status": 0 }.to_json]
    		end
    		rid = @ap.rid
    		case @ap.status
    		when 1
    			# puts "job in progress"
    		when 2
    			# puts "job finished"
    			retVal = [{"type": "files", "directory": rid.to_s, "hash": @ap.file_hash.to_s}.to_json]
    			return retVal
    		when -1
    			# puts "stopped with error"
    			return [{"file": "error"}.to_json]
    		end
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
	    			retVal = [{"type": "files", "directory": rid.to_s, "hash": @ap.file_hash.to_s}.to_json]
	    			return retVal
	    		when -1
	    			# puts "stopped with error"
	    			return [{"file": "error"}.to_json]
	    		end
    		end
    	end
		[{ "rid": rid, "status": @ap.status }.to_json]
    end
end