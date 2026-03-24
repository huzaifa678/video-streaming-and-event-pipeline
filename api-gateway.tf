resource "aws_apigatewayv2_api" "video_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.video_api.id
  name        = var.env == "dev" ? "0" : "1"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.env == "dev" ? 50  : 500
    throttling_rate_limit  = var.env == "dev" ? 100 : 1000
  }
}

resource "aws_apigatewayv2_integration" "lambda_ingest" {
  api_id           = aws_apigatewayv2_api.video_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

resource "aws_apigatewayv2_route" "ingest_route" {
  api_id    = aws_apigatewayv2_api.video_api.id
  route_key = "POST /events"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_ingest.id}"
}

resource "aws_apigatewayv2_integration" "lambda_query" {
  api_id           = aws_apigatewayv2_api.video_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.query_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "query_route" {
  api_id    = aws_apigatewayv2_api.video_api.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_query.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.video_api.execution_arn}/*/*"
}