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
                file_query = CGI::parse(request_string)["file"].first.to_s rescue nil
                if file_query.to_s != ""
                    # return matching files in Store
                    retVal = [{"type": "files", "directory": "sentinel_read"}.to_json]
                    Store.pluck(:item).each do |item|
                        if !(JSON(item)["file"].to_s =~ /#{file_query}/).nil?
                            retVal += JSON(item).to_json
                        end
                    end
                    retVal

                else
                    lat = CGI::parse(request_string)["lat"].first.to_f rescue nil
                    long = CGI::parse(request_string)["long"].first.to_f rescue nil
                    start_date = Date.parse(CGI::parse(request_string)["start"].first) rescue Time.now.to_date-14.days
                    end_date = Date.parse(CGI::parse(request_string)["end"].first) rescue Time.now.to_date
                    filter = CGI::parse(request_string)["filter"].first.to_s rescue ""

                    normalized_request = "lat=" + lat.to_s
                    normalized_request += "&long=" + long.to_s
                    normalized_request += "&start=" + start_date.to_s
                    normalized_request += "&end=" + end_date.to_s
                    normalized_request += "&filter=" + filter.to_s

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
                      "file-list": file_list,
                      "error-list": JSON.parse(@ap.error_list)
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

    def get_provision(params, logstr)
        retVal_type = container_format
        timeStart = Time.now.utc
        retVal_data = getData(params)
        timeEnd = Time.now.utc
        content = []
        case retVal_type.to_s
        when "JSON"
            retVal_data.each { |item| content << JSON(item) }
            content = content
            content_hash = Digest::SHA256.hexdigest(content.to_json)
        when "RDF"
            retVal_data.each { |item| content << item.to_s }
            content_hash = Digest::SHA256.hexdigest(content.to_s)
        else
            content = retVal_data.join("\n")
            content_hash = Digest::SHA256.hexdigest(content.to_s)
        end
        param_str = request.query_string.to_s

        createLog({
            "type": logstr,
            "scope": "all (" + retVal_data.count.to_s + " records)",
            "request": request.remote_ip.to_s}.to_json)

        {
            "content": content,
            "usage-policy": container_usage_policy.to_s,
            "provenance": getProvenance(content_hash, param_str, timeStart, timeEnd)
        }.stringify_keys
    end
    
end