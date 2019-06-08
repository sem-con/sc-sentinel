module DataWriteHelper
    require 'securerandom'

    def writeData(content, input, provenance)
        # collect relevant data
        res = input["resolution"].to_i rescue 60
        dir = content.first["directory"].to_s

        # list of files to be processed
        file_list = []
        content.each do |item|
            my_file = item["file"] rescue ""
            if !my_file.nil? && my_file != ""
                file_list << item
            end
        end

        # write provenance
        prov = Provenance.new(
            prov: provenance, 
            input_hash: Digest::SHA256.hexdigest(input.to_json),
            startTime: Time.now.utc)
        prov.save
        prov_id = prov.id

        # normalized request
        normalized_request = "resolution=" + res.to_s
        normalized_request += "&directory=" + dir.to_s
        normalized_request += "&prov_id=" + prov_id.to_s

        # create entry in AsyncProcess =====================
        rid = SecureRandom.uuid
        @ap = AsyncProcess.new(
            request: normalized_request,
            rid: rid,
            file_list: file_list.to_json,
            status: 0)
        @ap.save

        # setup job
        # simulate_job(rid)
        ApplicationJob.perform_later rid

        # return status
        render json: { "rid": rid, "status": 0, "message": "request created", "request": normalized_request },
               status: 200
    end
end