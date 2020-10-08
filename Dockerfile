#######################################################
# Step 1: Build the application in a container        #
#######################################################
# Download the official ASP.NET Core SDK image
# to build the project while creating the docker image
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 as build

ARG SONAR_PROJECT_KEY=Kudadigital_https-github.com-filetrust-mvp-icap-service-security-testing
ARG SONAR_OGRANIZAION_KEY=kudadigital 
ARG SONAR_HOST_URL=https://sonarcloud.io
ARG SONAR_TOKEN

# Install Sonar Scanner, Coverlet and Java (required for Sonar Scanner)
RUN apt-get update && apt-get install -y openjdk-11-jdk
RUN dotnet tool install --global dotnet-sonarscanner
RUN dotnet tool install --global coverlet.console

FROM ubuntu as base
RUN apt-get update && apt-get upgrade -y

FROM base as source
RUN apt-get install -y curl gcc make libtool autoconf automake automake1.11 unzip && \
    cd /tmp && mkdir c-icap
   
COPY ./c-icap/ /tmp/c-icap/c-icap/
COPY ./c-icap-modules /tmp/c-icap/c-icap-modules  

FROM source as build    
RUN cd /tmp/c-icap/c-icap &&  \
    autoreconf -i && \
    ./configure --prefix=/usr/local/c-icap && make && make install
        
RUN cd /tmp/c-icap/c-icap-modules && \
    autoreconf -i && \
    ./configure --with-c-icap=/usr/local/c-icap --prefix=/usr/local/c-icap && make && make install && \
    echo >> /usr/local/c-icap/etc/c-icap.conf && echo "Include gw_rebuild.conf" >> /usr/local/c-icap/etc/c-icap.conf
    
FROM base AS ms-package-signing
RUN  apt-get update \
  && apt-get install -y wget \
  && rm -rf /var/lib/apt/lists/*
  
RUN wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb

FROM ms-package-signing AS dotnet-sdk 
RUN apt-get install -y apt-transport-https && \
  apt-get update && \
  apt-get install -y dotnet-sdk-3.1
  
FROM dotnet-sdk AS dotnet-package-restore
COPY ./cloud-proxy-app/cloud-proxy-app.sln /src/cloud-proxy-app/cloud-proxy-app.sln 
COPY ./cloud-proxy-app/source/cloud-proxy-app.csproj /src/cloud-proxy-app/source/cloud-proxy-app.csproj
COPY ./cloud-proxy-app/test/cloud-proxy-app.test.csproj /src/cloud-proxy-app/test/cloud-proxy-app.test.csproj
RUN dotnet restore /src/cloud-proxy-app/cloud-proxy-app.sln 

FROM dotnet-package-restore AS dotnet-builder
COPY ./cloud-proxy-app /src/cloud-proxy-app
RUN dotnet publish -c Release /src/cloud-proxy-app/cloud-proxy-app.sln 

FROM ms-package-signing AS dotnet-runtime
RUN apt-get install -y apt-transport-https && \
  apt-get update && \
  apt-get install -y dotnet-runtime-3.1
    
FROM dotnet-runtime
COPY --from=build /usr/local/c-icap /usr/local/c-icap
COPY --from=build /run/c-icap /run/c-icap
COPY --from=dotnet-builder /src/cloud-proxy-app/source/bin/Release/netcoreapp3.1/publish /usr/local/bin

# Start Sonar Scanner
RUN dotnet sonarscanner begin \
  /k:"$SONAR_PROJECT_KEY" \
  /o:"$SONAR_OGRANIZAION_KEY" \
  /d:sonar.host.url="$SONAR_HOST_URL" \
  /d:sonar.login="$SONAR_TOKEN" \
  /d:sonar.cs.opencover.reportsPaths=/coverage.opencover.xml

# Restore NuGet packages
COPY *.csproj .
RUN dotnet restore

# Copy the rest of the files over
COPY . .

# Build and test the application
RUN dotnet publish 
  /p:CollectCoverage=true \
  /p:CoverletOutputFormat=opencover \
  /p:CoverletOutput="/coverage"
# End Sonar Scanner
RUN dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"

EXPOSE 1344
CMD ["/usr/local/c-icap/bin/c-icap","-N","-D"]
