Cloud Formation KDG user: https://awslabs.github.io/amazon-kinesis-data-generator/web/help.html


KDG login:  https://awslabs.github.io/amazon-kinesis-data-generator/web/producer.html?upid=us-east-1_DAJneI1Og&ipid=us-east-1:c0138ff6-50eb-4c5e-85c3-02950c9369e6&cid=40mmvs5ms96236ah0c83nak2qp&r=us-east-1
user: demo-dl-iac
password: demo2025

KDG template:
{
"year": "{{random.number({"min":1850,"max":1900})}}",
"month": "{{random.number({"min":1,"max":12})}}",
"day": "{{random.number({"min":1,"max":30})}}",
"firstname" : "{{name.firstName}}",
"lastname" : "{{name.lastName}}",
"city" : "{{address.city}}",
"transactionamount": {{random.number(
{
"min":10,
"max":150
}
)}}
}


