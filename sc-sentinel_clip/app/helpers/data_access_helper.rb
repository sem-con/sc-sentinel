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
            # just return all files
            retVal = [{"type": "files", "directory": "sentinel_clip"}.to_json]
            retVal += Store.pluck(:item).map{|x| JSON(x).to_json}
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
end