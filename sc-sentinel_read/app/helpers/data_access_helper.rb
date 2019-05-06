module DataAccessHelper
# response codes for sen2cor
# 0: request created (set in data_access_helper.rb)
# 1: request in progress (set in application_job.rb)
# 2: request successfully finished (set in application_job.rb)
# 
# errors
# -1: missing Requesst ID (set in data_access_helper.rb)
# -2: request terminated with error (set in application_job.rb)
# -3: missing attributes in request (set in application_job.rb)
    def getData(params)
    	require 'securerandom'

    	# check if request ID is present
    	if params["rid"].nil?
    		# check if request was sent before
    		request_string = request.query_string
            if request_string == ""
                # just return all downloads
                retVal = [{"type": "files", "directory": "sentinel_read"}.to_json]
                retVal += Store.pluck(:item).map{|x| JSON(x).to_json}
                retVal
            else
        		lat = CGI::parse(request_string)["lat"].first.to_f rescue nil
        		long = CGI::parse(request_string)["long"].first.to_f rescue nil
    			start_date = Date.parse(CGI::parse(request_string)["start"].first) rescue Time.now.to_date-14.days
    			end_date = Date.parse(CGI::parse(request_string)["end"].first) rescue Time.now.to_date

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
                    [{ "rid": rid, "status": 0, "message": "request created", "request": normalized_request }.to_json]
        		else
            		rid = @ap.rid
                    getData_response(rid)
                end
            end
    	else
    		rid = params["rid"].to_s
            getData_response(rid)
    	end
    end

    def getData_response(rid)
        @ap = AsyncProcess.find_by_rid(rid)
        if @ap.nil?
            status = -1
            message = "unknown Requesst ID"
        else
            status = @ap.status
            if @ap.file_list.to_s == ""
                file_list = []
            else
                file_list = JSON.parse(@ap.file_list)
            end
            request_string = @ap.request
            case status
            when 1
                message = "request in progress"
            when 2
                retVal = [
                    { 
                        "rid": rid,
                        "status": 2,
                        "message": "request successfully finished",
                        "request": request_string,
                        "file-list": file_list }.to_json,
                    {
                        "type": "files", 
                        "directory": "sentinel_read" }.to_json]
                JSON.parse(@ap.file_list).each do |my_file|
                    if File.file?("/data/sentinel_read/" + my_file.to_s)
                        my_hash = `sha256sum /data/sentinel_read/#{my_file} | head -c 64`
                        retVal += [{"file": my_file, "hash": my_hash.to_s}.to_json]
                    end
                end
                return retVal
            when -2
                retVal = [
                    { "rid": rid,
                      "status": -2,
                      "message": "request terminated with error",
                      "request": request_string,
                      "file-list": file_list
                  }.to_json]
                return retVal
            when -3
                message = "missing attributes in request"
            end
        end
        if message == ""
            if file_list.to_s == ""
                [{ "rid": rid, "status": status }.to_json]
            else
                [{ "rid": rid, "status": status, "request": request_string, "file-list": file_list }.to_json]
            end
        else
            if file_list.to_s == ""
                [{ "rid": rid, "status": status, "message": message, "request": request_string }.to_json]
            else 
                [{ "rid": rid, "status": status, "message": message, "request": request_string, "file-list": file_list }.to_json]
            end
        end
    end
end