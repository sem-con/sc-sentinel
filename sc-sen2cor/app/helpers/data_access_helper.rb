module DataAccessHelper
# response codes for sen2cor
# 0: request created (set in data_write_helper.rb)
# 1: request in progress (set in application_job.rb)
# 2: request successfully finished (set in application_job.rb)
# 
# errors
# -1: unknown Requesst ID (set in data_access_helper.rb)
# -2: request finished with errors (set in application_job.rb)
# -3: missing attributes in request (set in application_job.rb)
# -4: failed to access directory (set in application_job.rb)


    def getData(params)
        require 'securerandom'
        message = ""
        request_string = ""
        # check if request ID is present
        if params["rid"].nil?
            request_string = request.query_string
            if request_string == ""
                # just return all downloads
                retVal = [{"type": "files", "directory": "sen2cor"}.to_json]
                retVal += Store.pluck(:item).map{|x| JSON(x).to_json}
            else
                file_query = CGI::parse(request_string)["file"].first.to_s rescue nil
                if file_query.to_s != ""
                    # return matching files in Store
                    retVal = [{"type": "files", "directory": "sen2cor"}.to_json]
                    Store.pluck(:item).each do |item|
                        if !(JSON(item)["file"].to_s =~ /#{file_query}/).nil?
                            retVal += [JSON(item).to_json]
                        end
                    end
                else
                    # just return all downloads
                    retVal = [{"type": "files", "directory": "sen2cor"}.to_json]
                    retVal += Store.pluck(:item).map{|x| JSON(x).to_json}
                end
            end
            return retVal
        else
            rid = params["rid"].to_s
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
                    # puts "job finished"
                    retVal = [
                        { "rid": rid,
                          "status": 2,
                          "message": "request successfully finished",
                          "request": request_string,
                          "file-list": file_list }.to_json,
                        { "type": "files", 
                          "directory": "sen2cor" }.to_json]
                    return retVal
                when -2
                    retVal = [
                        { "rid": rid,
                          "status": -2,
                          "message": "request finished with errors",
                          "request": request_string,
                          "file-list": file_list,
                          "error-list": JSON.parse(@ap.error_list)
                      }.to_json,
                        { "type": "files", 
                          "directory": "sen2cor" }.to_json]
                    return retVal
                when -3
                    message = "missing attributes in request"
                when -4
                    message = "failed to access directory"
                end
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