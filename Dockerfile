FROM centos:latest
MAINTAINER Gaius Hammond <docker@gaius.org.uk>
RUN yum -y update
RUN yum -y install epel-release
RUN yum -y install python-bottle
EXPOSE 8080
COPY app.py /tmp/app.py
CMD ["python", "/tmp/app.py"]
# End of file