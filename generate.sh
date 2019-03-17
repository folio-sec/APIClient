openapi-generator generate \
  -i https://petstore.swagger.io/v2/swagger.json \
  -g swift4 --additional-properties projectName=PetstoreAPI \
  --additional-properties podSummary='Swagger Petstore' \
  --additional-properties podHomepage=https://github.com/folio-sec/APIClient \
  -o ./PetstoreAPI \
  -t ./swift4
