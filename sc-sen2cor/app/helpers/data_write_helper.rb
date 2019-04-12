module DataWriteHelper
    require 'securerandom'

    def writeData(content, input, provenance)
        # collect relevant data
        content = content.first rescue nil

        res = input["resolution"].to_i rescue 60
        dir = content["directory"].to_s
        normalized_request = "resolution=" + res.to_s
        normalized_request += "&directory=" + dir.to_s

       # create entry in Store ============================
       # write provenance
        prov = Provenance.new(
            prov: provenance, 
            input_hash: Digest::SHA256.hexdigest(input.to_json),
            startTime: Time.now.utc)
        prov.save
        prov_id = prov.id

        # write data
        my_store = Store.new(item: content.to_json, prov_id: prov_id)
        my_store.save

        # write log
        createLog({
            "type": "write",
            "scope": my_store.id.to_s,
            "request": request.remote_ip.to_s}.to_json)

        # create entry in AsyncProcess =====================
        status = 0
        # check if it was already processed
        @ap = AsyncProcess.find_by_request(normalized_request)
        if @ap.nil?
            # create entry in AsyncProcess
            rid = SecureRandom.uuid
            @ap = AsyncProcess.new(
                request: normalized_request,
                rid: rid,
                store_id: my_store.id,
                status: 0) # status 0 - job initialized
            @ap.save
            # setup job
            ApplicationJob.perform_later rid
        else
            status = 3
            rid = @ap.rid
        end

        # return status
        render json: { "rid": rid, "status": status },
               status: 200
return
        # write data to container store
        new_items = []
        begin
            if content.class == String
                if content == ""
                    render plain: "",
                           status: 500
                    return
                end
                content = [content]
            end

            # write provenance

            # write data
            content.each do |item|
                case container_format
                when "RDF", "CSV"
                    my_store = Store.new(item: item, prov_id: prov_id)
                else
                    my_store = Store.new(item: item.to_json, prov_id: prov_id)
                end
                my_store.save
                new_items << my_store.id
            end

            Provenance.find(prov_id).update_attributes(
                endTime: Time.now.utc)

            createLog({
                "type": "write",
                "scope": new_items.to_s,
                "request": request.remote_ip.to_s}.to_json)
            render plain: "",
                   status: 200

        rescue => ex
            puts "Error: " + ex.to_s
            render plain: "",
                   status: 500
        end
    end
end