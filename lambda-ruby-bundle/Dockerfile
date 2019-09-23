FROM lambci/lambda:ruby2.5

USER root

# workaround: https://github.com/moby/moby/issues/10180
RUN rpm --rebuilddb && \
    yum -y install \
      gcc \
      gcc-c++ \
      gmp-devel

ENTRYPOINT [""]
