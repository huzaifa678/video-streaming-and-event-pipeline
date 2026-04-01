import base64
import json

def lambda_handler(event, context):
    output = []

    for record in event['records']:
        try:
            payload = base64.b64decode(record['data']).decode('utf-8')

            obj = json.loads(payload)

            cleaned = json.dumps(obj) + "\n"

            output_record = {
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': base64.b64encode(cleaned.encode('utf-8')).decode('utf-8')
            }

        except Exception as e:
            output_record = {
                'recordId': record['recordId'],
                'result': 'Dropped',
                'data': record['data']
            }

        output.append(output_record)

    return {"records": output}