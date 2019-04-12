class ApplicationJob < ActiveJob::Base
	require "cgi"
	queue_as :default
 
	def perform(rid)
		@ap = AsyncProcess.find_by_rid(rid)
		if !@ap.nil?
			@ap.update_attributes(status: 1)

			res = CGI::parse(@ap.request)["resolution"].first.to_i rescue nil
			dir = CGI::parse(@ap.request)["directory"].first.to_s rescue nil

			if res.nil? or dir.nil?
				@ap.update_attributes(status: -2)
				return
			end

			# check if directory exists
			if !File.directory?("/data/" + dir.to_s)
				@ap.update_attributes(status: -3)
				return
			end

			# validate if hash is valid
			generateHash = "cd /data/" + dir.to_s + " && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | head -c 64"
			dir_hash = `#{generateHash}`
			input_hash = JSON.parse(Store.find(@ap.store_id).item)["hash"] rescue ""
			# !!! identify changed files on repeated execution
			# if dir_hash != input_hash
			# 	@ap.update_attributes(status: -4, request: dir_hash + " <-> " + input_hash)
			# 	return
			# end

			# create list of directories to process
			proc_dirs = []
			# file directly in directory
			proc_dirs += Dir.glob("/data/" + dir.to_s + "/S2?_MSIL1C_*.SAFE")
			# multiple dates in directory
			proc_dirs += Dir.glob("/data/" + dir.to_s + "/*/S2?_MSIL1C_*.SAFE")

			system("mkdir -p /data/" + rid.to_s)
			for my_dir in proc_dirs
				cmd = "/usr/src/app/Sen2Cor-02.05.05-Linux64/bin/L2A_Process --resolution " + res.to_s + " " + my_dir.to_s
				if system(cmd)
					copy_cmd = "cp " + my_dir.to_s + "/GRANULE/*/IMG_DATA/*_TCI.jp2 /data/" + rid.to_s
					if system(copy_cmd)
						@ap.update_attributes(status: -4, request: copy_cmd)
						break
					end
				else
					@ap.update_attributes(status: -1)
					break
				end
			end
			@ap.update_attributes(status: 2)
		end
	end
end
