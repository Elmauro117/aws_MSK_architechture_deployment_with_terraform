
//importar las lambdas existentes
data "aws_lambda_function" "producer" {
    function_name = "Lambda_producer_kafka"
}
data "aws_lambda_function" "consoomer" {
    function_name = "Consumer_lambda_msk"
}


//Añadir los triggers a las Lambdas
//Lmbda PROD
resource "aws_lambda_event_source_mapping" "lambda_test_sqs_trigger" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = data.aws_lambda_function.producer.arn
  depends_on       = [aws_sqs_queue.queue]
  batch_size       =  5
  maximum_batching_window_in_seconds = 2

  scaling_config  {
    maximum_concurrency =   2
    }
  
}

// Lambda Consoomer
resource "aws_lambda_event_source_mapping" "lambda_2_test_MSK_trigger" {
  event_source_arn = aws_msk_cluster.cluster.arn /// El TRIGGER que es el MSK
  function_name    = data.aws_lambda_function.consoomer.arn
  depends_on       = [aws_msk_cluster.cluster]
  topics = ["demo-testing2"]
  
  batch_size       =  5
  maximum_batching_window_in_seconds = 2

  enabled           = true
  starting_position = "LATEST"
}

// añadir la VPC y las subredes al Lambda_consumer
resource "aws_lambda_vpc_configuration" "consumer_conf" {
  function_name    = data.aws_lambda_function.producer.arn
  vpc_id     = data.aws_vpc.existing_vpc.id
  subnet_ids = [data.aws_subnet.private_subnet_1.id, data.aws_subnet.private_subnet_2.id]

  security_group_ids = [aws_security_group.sg.id]
}


