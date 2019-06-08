class ApplicationJob < ActiveJob::Base
	require "cgi"
	require 'securerandom'
	queue_as :default
 
	def perform(rid)
        @ap = AsyncProcess.find_by_rid(rid)
        if !@ap.nil?
            @ap.update_attributes(status: 1)

            res = CGI::parse(@ap.request)["resolution"].first.to_i rescue nil
            dir = CGI::parse(@ap.request)["directory"].first.to_s rescue nil
            prov_id = CGI::parse(@ap.request)["prov_id"].first.to_s rescue nil

            if res.nil? or dir.nil? or prov_id.nil?
                @ap.update_attributes(status: -3)
                return
            end

            # check if directory exists
            if !File.directory?("/data/" + dir.to_s)
                @ap.update_attributes(status: -4)
                return
            end

            error_list = []
            # iterate over all files
            JSON.parse(@ap.file_list).each do |item|
                my_file = item["file"]
                my_hash = item["hash"]

                # check if hash value is valid
                cmd = "sha256sum /data/" + dir.to_s + "/" + my_file.to_s + " | head -c 64"
                current_hash = `#{cmd}`
                if current_hash != my_hash
                    error_list += [{"file": my_file, "error": "hash does not match"}]
                    next
                end

                # unzip to tmp-uuid folder
                tmp_uuid = SecureRandom.uuid
                if !system("mkdir -p /data/sen2cor/" + tmp_uuid)
                    error_list += [{"file": my_file, "error": "failed to create tmp directory"}]
                    next
                end
                if !system("unzip /data/" + dir.to_s + "/" + my_file.to_s + " -d /data/sen2cor/" + tmp_uuid)
                    error_list += [{"file": my_file, "error": "failed to unzip file"}]
                    next
                end

                # run L2A_Process
                if !system("/usr/src/app/Sen2Cor-02.05.05-Linux64/bin/L2A_Process --resolution " + res.to_s + " /data/sen2cor/" + tmp_uuid + "/*.SAFE")
                    error_list += [{"file": my_file, "error": "failed to run L2A_Process"}]
                    next
                end

                # copy TCI to /data/sen2cor folder
                new_file = `ls /data/sen2cor/#{tmp_uuid}/S2A_MSIL2A*/GRANULE/*/IMG_DATA/R#{res.to_s}m/*TCI*.jp2 | xargs -n 1 basename`.strip
                if new_file.to_s == ""
                    error_list += [{"file": new_file.to_s, "error": "failed to get new TCI"}]
                    next
                end
                if !system("cp /data/sen2cor/" + tmp_uuid + "/S2A_MSIL2A*/GRANULE/*/IMG_DATA/R" + res.to_s + "m/*TCI*.jp2 /data/sen2cor/")
                    error_list += [{"file": my_file, "error": "failed to copy TCI"}]
                    next
                end

                # delete tmp-uuid
                if !system("rm -rf /data/sen2cor/" + tmp_uuid)
                    error_list += [{"directory": tmp_uuid, "error": "failed to delete tmp directory"}]
                    next
                end

                # check if file exists
                all_files = Store.pluck(:item).map{|x| JSON.parse(x)["file"]}
                if !all_files.include?(new_file)
                    # create hash of TCI
                    cmd = "sha256sum /data/sen2cor/" + new_file.to_s + " | head -c 64"
                    new_hash = `#{cmd}`
                    if new_hash.to_s == ""
                        error_list += [{"file": new_file.to_s, "error": "failed to create hash from TCI"}]
                        next
                    end

                    # write into Store
                    @my_store = Store.new(item: {"file": new_file.to_s, "hash": new_hash.to_s}.to_json, prov_id: prov_id)
                    @my_store.save
                end
            end
            if error_list.count > 0
                @ap.update_attributes(status: -2, error_list: error_list.to_json)
            else
                @ap.update_attributes(status: 2)
            end
        end

	end
end
