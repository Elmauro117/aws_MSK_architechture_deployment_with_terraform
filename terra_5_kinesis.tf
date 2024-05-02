
//importar S3
data "aws_s3_bucket" "bucket_msk" {
  bucket = "XXXXXXXXXXXXXXX"            ## BUCKT NAME
}


// ROL para el firehose
resource "aws_iam_role" "firehose_role" {
  name               = "firehose-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "firehose.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "s3_full_access_attachment" {
  name       = "s3-full-access-attachment"
  roles      = [aws_iam_role.firehose_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

//Crear el Firehose
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "stream_msk"
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn = aws_iam_role.firehose_role.arn
    bucket_arn = data.aws_s3_bucket.bucket_msk.arn
    #prefix = "firehose-output/"
    buffer_size = 2
    buffer_interval = 60
    #compression_format = "UNCOMPRESSED"
  }
}