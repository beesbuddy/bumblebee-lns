# docker build -t gotthardp/bumblebee .
# docker run --restart unless-stopped --detach --name lorawan --hostname lorawan \
#   --volume /root/storage:/storage --publish 8081:8080/tcp --publish 1680:1680/udp gotthardp/bumblebee
FROM tedsluis/raspbian.minimal.arm7
RUN apt-get update && apt-get install -y wget git npm make

RUN apt-get install -y libssl-dev
RUN apt-get install -y ncurses-dev
RUN  wget http://www.erlang.org/download/otp_src_20.0.tar.gz
RUN  tar -xzvf otp_src_20.0.tar.gz
RUN  cd otp_src_20.0/ && ./configure && make && make install

RUN rm otp_src_20.0.tar.gz
RUN rm -R otp_src_20.0/
RUN mkdir bumblebee
RUN wget https://github.com/gotthardp/bumblebee/releases/download/v0.4.12/bumblebee-0.4.12.tar.gz
RUN mv bumblebee-0.4.12.tar.gz bumblebee/
RUN cd bumblebee && tar -zxvf bumblebee-0.4.12.tar.gz

# volume for the mnesia database and logs
RUN mkdir -p /storage
VOLUME /storage
# data from port_forwarders
EXPOSE 1680/udp
# admin interface
EXPOSE 8080/tcp
ENV BUMBLEBEE_LNS_HOME=/storage
WORKDIR /bumblebee
CMD bin/bumblebee-lns
