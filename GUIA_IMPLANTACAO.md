# Guia de Implantação - Demo Data Lake AWS

Este guia explica como implantar a demonstração completa do Data Lake na AWS usando uma abordagem híbrida com CloudFormation, Terraform e configuração manual.

## 📋 Pré-requisitos

- **AWS CLI** configurado com credenciais apropriadas
- **Terraform** instalado (versão 1.0+)
- **Permissões AWS** para todos os serviços utilizados
- **Conta AWS** com acesso ao QuickSight

## 🏗️ Arquitetura da Solução

```
KDG → Kinesis Firehose → S3 (raw) → Lambda → Glue ETL → S3 (processed) → Athena → QuickSight
```

**Componentes:**
- **Cognito**: Autenticação para KDG
- **Kinesis Firehose**: Ingestão de dados em tempo real
- **S3**: Armazenamento do data lake (raw + processed)
- **Lambda**: Transformação de dados e trigger do Glue
- **Glue**: ETL e conversão para Parquet
- **Athena**: Consultas SQL no data lake
- **QuickSight**: Visualização e dashboards
- **CloudWatch**: Monitoramento e logs

## 🚀 Passos de Implantação

### Passo 1: Criar Usuário Cognito (CloudFormation)

**Por que CloudFormation?**
- Template oficial da AWS para KDG
- Configuração de IAM otimizada e testada
- Processo simplificado e confiável

**Instruções:**
1. Acesse: https://awslabs.github.io/amazon-kinesis-data-generator/web/help.html
2. Clique em **"Create a Cognito User with CloudFormation"**
3. Faça login no AWS Console
4. Execute o template CloudFormation
5. Anote as credenciais geradas:
   - **Username**: (definido por você)
   - **Password**: (definido por você)
   - **KDG URL**: (gerado pelo CloudFormation)

### Passo 2: Implantar Infraestrutura (Terraform)

**Por que Terraform?**
- Infraestrutura como código
- Versionamento e reutilização
- Controle granular dos recursos

**Comandos:**
```bash
# 1. Inicializar Terraform
terraform init

# 2. Revisar o plano
terraform plan

# 3. Aplicar a infraestrutura
terraform apply
```

**Recursos criados:**
- S3 Bucket para data lake
- Kinesis Firehose delivery stream
- Funções Lambda (transformação + trigger)
- Glue Database, Job e Crawler
- Tabela Athena
- Workgroup Athena
- Roles e políticas IAM
- Log Groups CloudWatch

### Passo 3: Configurar QuickSight (Manual)

**Por que Manual?**
- Requer credenciais específicas do usuário
- Configurações dependem da organização
- Integração interativa com Athena

**Instruções:**
1. **Ativar QuickSight:**
   - Acesse AWS QuickSight Console
   - Escolha **Standard Edition**
   - Configure permissões para S3 e Athena

2. **Criar Data Source:**
   - Tipo: **Athena**
   - Nome: `data-lake-demo-source`
   - Workgroup: `data-lake-demo-workgroup`
   - Database: `data_lake_demo_database`
   - Tabela: `processed_data`

3. **Criar Dataset:**
   - Selecione a tabela `processed_data`
   - Configure refresh automático (opcional)

4. **Criar Dashboard:**
   - Gráficos sugeridos:
     - Distribuição por cidade
     - Valores de transação por período
     - Contagem de registros por estado
     - Timeline de ingestão

## 🧪 Testando a Solução

### 1. Enviar Dados via KDG
```json
{
  "year": "{{random.number({\"min\":1850,\"max\":1900})}}",
  "month": "{{random.number({\"min\":1,\"max\":12})}}",
  "day": "{{random.number({\"min\":1,\"max\":30})}}",
  "firstname": "{{name.firstName}}",
  "lastname": "{{name.lastName}}",
  "city": "{{address.city}}",
  "state": "{{address.state}}",
  "country": "{{address.country}}",
  "zipcode": "{{address.zipCode}}",
  "street": "{{address.streetAddress}}",
  "transactionamount": {{random.number({"min":10,"max":150})}}
}
```

### 2. Verificar Fluxo de Dados
- **S3 Raw** (1 minuto): `s3://bucket/raw/year=2025/month=08/day=09/`
- **S3 Processed** (2-3 minutos): `s3://bucket/processed/year=2025/month=08/day=09/`
- **Athena**: `SELECT COUNT(*) FROM processed_data;`

### 3. Consultas Athena de Exemplo
```sql
-- Contagem total de registros
SELECT COUNT(*) FROM processed_data;

-- Top 10 cidades
SELECT city, COUNT(*) as total 
FROM processed_data 
GROUP BY city 
ORDER BY total DESC 
LIMIT 10;

-- Valor médio de transações por estado
SELECT state, AVG(transactionamount) as avg_amount
FROM processed_data 
GROUP BY state 
ORDER BY avg_amount DESC;
```

## 📊 Monitoramento

**CloudWatch Log Groups criados:**
- `/aws/kinesisfirehose/data-lake-demo-firehose`
- `/aws/lambda/data-lake-demo-transformer`
- `/aws/lambda/data-lake-demo-glue-trigger`
- `/aws-glue/jobs/logs-v2`
- `/aws-glue/jobs/error`

## 🔧 Solução de Problemas

### Dados não aparecem no S3
- Verificar se KDG está enviando para o stream correto
- Aguardar 1 minuto (buffer do Firehose)
- Verificar logs do Firehose no CloudWatch

### Glue Job falha
- Verificar logs em `/aws-glue/jobs/error`
- Confirmar permissões IAM do Glue
- Verificar se dados estão no formato JSON correto

### Athena não retorna dados
- Executar `MSCK REPAIR TABLE processed_data;`
- Verificar se partições estão sendo criadas
- Confirmar localização S3 da tabela

## 🧹 Limpeza

```bash
# Esvaziar bucket S3 manualmente (console AWS)
# Depois executar:
terraform destroy
```

**Nota:** O bucket S3 deve ser esvaziado manualmente antes do `terraform destroy` devido ao versionamento.

## 📝 Notas Importantes

### Por que não tudo em Terraform?

1. **Cognito User (CloudFormation)**
   - Template oficial e otimizado da AWS
   - Configuração complexa de IAM simplificada
   - Reduz chance de erros de configuração

2. **QuickSight (Manual)**
   - Requer credenciais específicas do usuário
   - Configurações variam por organização
   - Integração interativa funciona melhor
   - Políticas IAM complexas e específicas

3. **Benefícios da Abordagem Híbrida**
   - **Terraform**: Infraestrutura core reutilizável
   - **CloudFormation**: Componentes específicos da AWS
   - **Manual**: Configurações dependentes do usuário
   - **Resultado**: Solução robusta e portável

## 🎯 Próximos Passos

1. **Personalizar Dashboards** no QuickSight
2. **Ajustar Template KDG** conforme necessário
3. **Configurar Alertas** no CloudWatch
4. **Implementar Backup** dos dados processados
5. **Otimizar Custos** ajustando recursos conforme uso

---

**Desenvolvido para demonstração de Data Lake na AWS**  
**Versão: 1.0**  
**Data: Agosto 2025**