# FROM semcon/sc-base
FROM semcon/sc-base_sen2cor
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

WORKDIR /usr/src/app
# ENV SEN2COR_VERSION='02.05.05'
# ARG SEN2COR_DIRECTORY='2.5.5' 
# ARG SEN2COR="Sen2Cor-${SEN2COR_VERSION}-Linux64.run"
# RUN wget "http://step.esa.int/thirdparties/sen2cor/${SEN2COR_DIRECTORY}/${SEN2COR}" && \
#     bash ${SEN2COR} && \
# .    rm ${SEN2COR}

COPY . .
CMD ["./script/init.sh"]

EXPOSE 3000