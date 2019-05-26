class ApplicationJob < ActiveJob::Base
    require "cgi"
    require "date"
    queue_as :default
 
    def perform(rid)
        $DOWNLOAD_DIR = "/data/sentinel_read"

        @ap = AsyncProcess.find_by_rid(rid)
        if !@ap.nil?
            @ap.update_attributes(status: 1)

            lat = CGI::parse(@ap.request)["lat"].first.to_f rescue nil
            long = CGI::parse(@ap.request)["long"].first.to_f rescue nil
            start_date = Date.parse(CGI::parse(@ap.request)["start"].first) rescue nil
            end_date = Date.parse(CGI::parse(@ap.request)["end"].first) rescue nil
            filter = CGI::parse(@ap.request)["filter"].first.to_s rescue ""

            if lat.nil? or long.nil? or start_date.nil? or end_date.nil?
                @ap.update_attributes(status: -3)
            else
                error_list = []
                # get list of files
                cmd = "python script/eomex_list.py -c " + lat.to_s + " " + long.to_s + " -begin " + start_date.to_s + " -end " + end_date.to_s
                retVal = `#{cmd}`
                file_list = JSON.parse(retVal.split("\n").last)["filelist"].map{ |x| x.split("/").last }
                @ap.update_attributes(file_list: file_list.to_json)

                # create list of already downloaded files
                all_files = Store.pluck(:item).map{|x| JSON.parse(x)["file"]}
                file_list.each do |file_dl|
                    # check if filename matches filter
                    if !(file_dl =~ /#{filter}/).nil?
                        # check if file_dl is already downloaded in store
                        if !all_files.include?(file_dl)
                            # download file
                            filename = File.basename(file_dl)
                            # check if file already exists
                            if File.file?($DOWNLOAD_DIR + filename)
                                retVal = `sha256sum " + $DOWNLOAD_DIR + "/#{filename} | head -c 64`
                                if retVal.to_s != ""
                                    @my_store = Store.new(item: {"file": my_file, "hash": retVal.to_s}.to_json)
                                    @my_store.save
                                else
                                    delete_file = "rm -f " + filename
                                    if system(delete_file)
                                        error_list += [{"filename": my_file, "error": "file already existed but can't create hash value (file deleted)"}]
                                    end
                                end
                            else
                                download_file = "wget -P " + $DOWNLOAD_DIR 
                                download_file += " ftp://galaxy.eodc.eu/" + file_dl[file_dl.index("copernicus.eu/s2a_prd_msil1c")..-1]
                                if system(download_file)  # download successfull
                                    # create hash value
                                    retVal = `sha256sum " + $DOWNLOAD_DIR + "/#{filename} | head -c 64`
                                    if retVal.to_s != ""
                                        @my_store = Store.new(item: {"file": my_file, "hash": retVal.to_s}.to_json)
                                        if !@my_store.save
                                            error_list += [{"filename": my_file, "error": "adding file to list failed"}]
                                        end
                                    else
                                        delete_file = "rm -f " + filename
                                        if system(delete_file)
                                            error_list += [{"filename": my_file, "error": "download successfull but can't create hash value (file deleted)"}]
                                        else
                                            error_list += [{"filename": my_file, "error": "download successfull but can't create hash value (file deleted)"}]
                                        end
                                    end
                                else
                                    # otherwise delete partial downloaded
                                    delete_file = "rm -f " + filename
                                    if system(delete_file)
                                        error_list += [{"filename": my_file, "error": "download failed (partial file deleted)"}]
                                    else
                                        error_list += [{"filename": my_file, "error": "download failed"}]
                                    end
                                end
                            end
                        end
                    end
                end

                if error_list.count > 0
                    @ap.update_attributes(status: -2, error_list: error_list.to_json)
                else
                    @ap.update_attributes(status: 2)
                end


                # cmd = "python script/eomex_download.py -c " + lat.to_s + " " + long.to_s + " -begin " + start_date.to_s + " -end " + end_date.to_s + " -o /data/sentinel_read -skipifexist"
                # if system(cmd)
                #     all_files = Store.pluck(:item).map{|x| JSON.parse(x)["file"]}
                #     for my_file in file_list
                #         if all_files.include?(my_file)
                #             @my_store = Store.where("item like ?", "%#{my_file}")
                #             if @my_store.count == 1
                #                 retVal = `sha256sum /data/sentinel_read/#{my_file} | head -c 64`
                #                 if retVal.to_s != ""
                #                     @my_store.first.update_attributes(item: {"file": my_file, "hash": retVal.to_s}.to_json)
                #                 end
                #             end
                #         else
                #             retVal = `sha256sum /data/sentinel_read/#{my_file} | head -c 64`
                #             if retVal.to_s != ""
                #                 @my_store = Store.new(item: {"file": my_file, "hash": retVal.to_s}.to_json)
                #                 @my_store.save
                #             end
                #         end
                #     end
                #     @ap.update_attributes(status: 2)
                # else
                #     @ap.update_attributes(status: -2)
                # end
            end
        end

    end
end
