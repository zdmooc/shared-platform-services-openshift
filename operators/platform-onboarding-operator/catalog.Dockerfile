FROM quay.io/operator-framework/opm:v1.74.0
LABEL operators.operatorframework.io.index.configs.v1=/configs
COPY catalog/mayabank-platform-operator /configs
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
